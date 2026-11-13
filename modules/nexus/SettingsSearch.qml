pragma Singleton

import "../../utils/scripts/fuzzymatch.js" as Search
import QtQuick
import qs.modules.nexus

// Runs the settings search field against both the page list and SettingsIndex,
// so typing "hover" finds the hover toggles themselves rather than only the
// pages they happen to live on.
//
// Everything matched on is normalised once, when the index is built, and the
// query does the rest. Both lists are rebuilt when the language changes,
// because the labels they hold are translated.
QtObject {
    id: root

    // How many results each list gives back before it is cut off. The settings
    // list is long enough that an open ended query would otherwise fill the
    // sidebar with near misses.
    readonly property int maxPages: 8
    readonly property int maxSettings: 40

    readonly property list<var> pageEntries: PageRegistry.pages.map((page, idx) => ({
                pageIdx: idx,
                label: page.label,
                subtext: page.description,
                keywords: page.keywords ?? "",
                icon: page.icon,
                noFill: page.noFill ?? false,
                // Results come back ranked, not in sidebar order, so they are one group
                // rather than the categories the unfiltered list is split into
                category: "results"
            }))

    readonly property list<var> settingEntries: SettingsIndex.entries.map(entry => {
        const pageIdx = PageRegistry.indexOfKey(entry.page);
        const page = PageRegistry.pages[pageIdx];
        return {
            pageIdx,
            path: entry.path,
            // Identifies the entry across rebuilds of the result list, so the one that
            // was opened stays marked as open while the query is edited around it
            key: `${entry.page}/${entry.path.join(",")}/${entry.section ?? ""}/${entry.label}`,
            label: entry.label,
            subtext: entry.subtext ?? "",
            section: entry.section ?? "",
            title: entry.title ?? "",
            keywords: entry.keywords ?? "",
            // The page's own name in the sidebar, which is not always what the
            // page calls itself once open ("Connected devices" vs "Bluetooth")
            pageLabel: page?.label ?? "",
            icon: page?.icon ?? "settings",
            noFill: page?.noFill ?? false
        };
    })

    readonly property list<var> preparedPages: root.pageEntries.map(entry => Search.prepare(entry))
    readonly property list<var> preparedSettings: root.settingEntries.map(entry => Search.prepare(entry))

    function queryPages(query: string): var {
        return Search.search(query, root.preparedPages, root.maxPages).map(result => result.entry);
    }

    function querySettings(query: string): var {
        return root.querySettingsScored(query).map(result => result.entry);
    }

    // The same results with their scores kept, for callers that want to be stricter than the
    // sidebar is. The sidebar can afford to show a near miss - it is the only list on screen, and
    // scrolling past one costs nothing - while the launcher is mixing settings in with apps and
    // actions, where a loose match reads as a wrong answer rather than a further one
    function querySettingsScored(query: string): var {
        return Search.search(query, root.preparedSettings, root.maxSettings);
    }
}
