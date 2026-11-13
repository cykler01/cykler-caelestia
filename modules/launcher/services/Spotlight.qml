pragma Singleton

import "../../../utils/scripts/fuzzymatch.js" as Fuzzy
import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus

// What the launcher shows for plain text: the apps, plus an answer when the text is a sum.
//
// Everything with a mode of its own stays in it. Settings (">settings"), files (">find") and the
// actions (">") are all searched over far more rows than the app list, and all of them use words -
// "settings", "display", "network" - that name an app too, so mixed in they crowded out the thing
// actually being looked for. This builds the rows and ranks the groups; each mode runs its own
// search and its results come through here only to be drawn the same way.
//
// Apps still go through Apps (fzf or fuzzysort, weighted by how often you launch them) - that is
// not replaced, because the app list is the launcher's main job and its ranking is tuned.
Singleton {
    id: root

    // Categories, used as group keys and to pick a heading
    readonly property string catCalc: "calc"
    readonly property string catApps: "apps"
    readonly property string catSettings: "settings"
    readonly property string catActions: "actions"
    readonly property string catFiles: "files"

    // How many of each source's results are worth showing next to the others. A unified list that is
    // all apps is just the app list with extra steps
    readonly property int maxApps: Config.launcher.maxShown
    // ...and how many rows in total, however they divide up. The launcher is a list you glance at;
    // past a certain length you are reading rather than picking
    readonly property int maxResults: Config.launcher.maxShown
    // The settings mode has the list to itself, so it can fill it
    readonly property int maxSettings: Config.launcher.maxShown

    // Below this a group is noise rather than an answer, and is left out - unless nothing clears it,
    // since some answer beats "No results"
    readonly property real groupThreshold: 0.3
    // A single result has to clear this to ride along under a group its best hit earned. The
    // sidebar's own bar is lower on purpose (see SettingsSearch.querySettingsScored)
    readonly property real itemThreshold: 0.45
    // Arithmetic that parses is an unambiguous answer, so everything else has to be a good deal
    // more convincing to be shown beside it - a digit loosely matching some setting's text is not
    readonly property real besideCalcThreshold: 0.55

    // The expression handed to the calculator, so a stale answer is not shown against new text.
    // libqalculate is asked off the main thread (an expression can take a while to parse), and the
    // result arrives on Qalculator.rawResult, which the result list is bound to
    property string pendingExpr

    // Where a setting actually lives, the same trail the settings sidebar shows. Without the
    // sub-page there is no telling the two "Dino game" toggles apart, which both sit under
    // Panels in a section called Notifications
    function settingTrail(entry: var): string {
        const parts = [entry.pageLabel];
        if (entry.path.length > 0 && entry.title && entry.title !== entry.pageLabel)
            parts.push(entry.title);
        const path = parts.join(" › ");
        return entry.section ? `${path} · ${entry.section}` : path;
    }

    function categoryName(category: string): string {
        switch (category) {
        case root.catCalc:
            return Tr.trCtx("Calculator", "search result group");
        case root.catSettings:
            return Tr.trCtx("Settings", "search result group");
        case root.catFiles:
            return Tr.trCtx("Files", "search result group");
        case root.catActions:
            return Tr.trCtx("Actions", "search result group");
        default:
            return Tr.trCtx("Applications", "search result group");
        }
    }

    // The text as arithmetic, or "" when it is prose. Both a digit and an operator are needed, so a
    // bare "100" and an app called "7 Days" are not treated as sums
    function mathExpr(text: string): string {
        const expr = text.trim();
        if (!/[0-9]/.test(expr))
            return "";
        if (!/[-+*/^%()]|\b(sqrt|sin|cos|tan|log|ln|abs)\b/.test(expr))
            return "";
        return expr;
    }

    // Starts the calculator off on new text. Called as the text changes rather than from query(),
    // which has to stay free of side effects: it runs inside the result list's own binding
    function prime(text: string): void {
        const expr = root.mathExpr(text);
        if (expr === root.pendingExpr)
            return;

        root.pendingExpr = expr;
        if (expr)
            Qalculator.evalAsync(expr);
    }

    // How well a source's own best hit actually answers the query, on the shared 0-1 scale. The
    // sources cannot be compared any other way: fzf scores are unbounded, and a list position says
    // nothing about whether the first entry is a good answer or merely the least bad one
    function confidence(query: string, fields: var): real {
        const results = Fuzzy.search(query, [Fuzzy.prepare(fields)], 1);
        return results.length > 0 ? results[0].score : 0;
    }

    // The whole result list, already ordered: the best group first, its own best hit at the top.
    // Each entry carries `firstOfGroup`, since the list draws its own headings rather than relying
    // on a model role the script model behind it does not have
    function query(search: string, apps: var): var {
        const text = search.trim();
        if (!text)
            return [];

        const groups = [];

        // Arithmetic has one answer, so when it parses it is the answer
        const hasCalc = root.pendingExpr && root.pendingExpr === root.mathExpr(text) && !!Qalculator.rawResult;
        if (hasCalc)
            groups.push({
                score: 1,
                items: [
                    {
                        category: root.catCalc,
                        title: Qalculator.rawResult,
                        subtitle: text,
                        icon: "function",
                        kind: "calc",
                        payload: Qalculator.rawResult
                    }
                ]
            });

        if (apps.length > 0) {
            const items = apps.slice(0, root.maxApps).map(entry => ({
                        category: root.catApps,
                        title: entry.name,
                        subtitle: entry.genericName || entry.comment || "",
                        icon: "",
                        iconSource: entry.icon,
                        kind: "app",
                        payload: entry
                    }));
            groups.push({
                score: root.confidence(text, {
                    label: items[0].title,
                    subtext: items[0].subtitle
                }),
                items
            });
        }

        const bar = hasCalc ? root.besideCalcThreshold : root.groupThreshold;
        const strong = groups.filter(g => g.score >= bar);
        const keep = strong.length > 0 ? strong : groups;
        keep.sort((a, b) => b.score - a.score);

        const out = [];
        for (const group of keep)
            group.items.forEach((item, i) => out.push(Object.assign({}, item, {
                        firstOfGroup: i === 0
                    })));

        // Trimmed at the end rather than per group, so a query that is plainly one app's name does
        // not lose it to make room for three actions
        return root.markGroups(out.slice(0, root.maxResults));
    }

    // Re-marks which rows start a group, after a slice may have cut the first row of one off.
    // A single group needs no heading: typing an app's name should look like the app list it
    // replaced, not like the app list with "Applications" written over it
    function markGroups(items: var): var {
        const groups = new Set(items.map(item => item.category));
        let last = "";
        return items.map(item => {
            const first = groups.size > 1 && item.category !== last;
            last = item.category;
            return Object.assign({}, item, {
                firstOfGroup: first
            });
        });
    }

    // The ">settings " mode: settings on their own, where they are not competing with the apps.
    // With nothing typed after the prefix there is nothing to search for, so the one result opens
    // the settings window itself - which is what ">settings" alone is asking for
    function querySettings(search: string, settings: var): var {
        if (!search.trim())
            return [
                {
                    category: root.catSettings,
                    title: Tr.tr("Open settings"),
                    subtitle: Tr.tr("Or keep typing to search them"),
                    icon: "settings",
                    kind: "settingsWindow",
                    firstOfGroup: true
                }
            ];

        return settings.filter(result => result.score >= root.itemThreshold).slice(0, root.maxSettings).map((result, i) => ({
                    category: root.catSettings,
                    title: result.entry.label,
                    subtitle: root.settingTrail(result.entry),
                    icon: result.entry.icon,
                    kind: "setting",
                    payload: result.entry,
                    firstOfGroup: i === 0
                }));
    }

    // Does whatever the result is for, so the list delegate does not have to know one kind from
    // another. `list` is the AppList, which the launcher actions need to reach the search field and
    // the screen state
    function activate(result: var, list: var): void {
        switch (result.kind) {
        case "app":
            Apps.launch(result.payload);
            list.screenState.launcher = false;
            break;
        case "setting":
            // Settings live in their own window, so this opens Nexus already on the row rather than
            // on whichever page it happens to sit in (see modules/nexus/WindowFactory.qml)
            WindowFactory.create(null, {
                startSetting: result.payload
            });
            list.screenState.launcher = false;
            break;
        case "file":
            Quickshell.execDetached(["xdg-open", result.payload]);
            list.screenState.launcher = false;
            break;
        case "none":
            break;
        case "settingsWindow":
            WindowFactory.create();
            list.screenState.launcher = false;
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", result.payload]);
            list.screenState.launcher = false;
            break;
        case "action":
            result.payload.onClicked(list);
            break;
        default:
            break;
        }
    }
}
