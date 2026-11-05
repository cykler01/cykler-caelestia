pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.services

// The data the desktop widgets have to fetch or sample, kept here rather than inside the cards.
//
// A card only exists while its desktop is in view: Background.qml unloads the whole widget stack as soon as
// windows cover the desktop, and rebuilds every card from scratch when they uncover it. Anything a card held
// therefore started over at that moment - GitHub went back to "Loading..." while curl went out again, and the
// system card came back with empty graphs and zero readings until its first sample landed. What is expensive
// to obtain is kept a level up instead, where unloading the cards does not clear it, so a card that comes back
// draws immediately from what is already here and only refreshes behind the scenes.
Singleton {
    id: root

    readonly property var widgetConfig: GlobalConfig.background.desktopWidgets
    readonly property var entries: root.widgetConfig.entries.values

    // --- System readings ---
    // The cadence the system card samples at, slowed down with everything else on battery
    readonly property int sampleInterval: 3000 * PowerSaving.pollSlowdown

    // Whether a system widget is actually placed, so a layout without one doesn't keep the readings ticking
    readonly property bool wantsSystem: root.widgetConfig.enabled && root.entries.some(e => e.enabled && e.id === "resources")
    // Likewise for the GitHub calendar: a desktop without the card shouldn't fetch one
    readonly property bool wantsGithub: root.widgetConfig.enabled && root.entries.some(e => e.enabled && e.id === "github")
    property real cpu
    property real memory
    property real disk
    // Celsius; the card formats it with the configured sensor unit. Not a percentage, so it only ever feeds the
    // rings, which read it against a full-scale of 100 degrees
    property real temperature
    property var cpuHistory: []
    property var ramHistory: []
    property var diskHistory: []

    function push(history: var, value: real): var {
        const next = history.concat([Math.max(0, Math.min(1, value))]);
        return next.length > 24 ? next.slice(next.length - 24) : next;
    }

    function sample(): void {
        root.cpu = Cpu.percentage;
        root.memory = Memory.percentage;
        root.disk = Storage.percentage;
        root.temperature = Cpu.temperature;
        root.cpuHistory = root.push(root.cpuHistory, root.cpu);
        root.ramHistory = root.push(root.ramHistory, root.memory);
        root.diskHistory = root.push(root.diskHistory, root.disk);
    }

    function clearSystem(): void {
        root.cpuHistory = [];
        root.ramHistory = [];
        root.diskHistory = [];
    }

    // The readings live in the services, which stop polling as soon as nothing references them. Holding a
    // reference here keeps them live while the desktop is hidden, so a card that comes back shows the current
    // value rather than waiting for its first tick
    ServiceRef {
        service: root.wantsSystem ? Cpu : null
    }

    ServiceRef {
        service: root.wantsSystem ? Memory : null
    }

    ServiceRef {
        service: root.wantsSystem ? Storage : null
    }

    Timer {
        interval: root.sampleInterval
        running: root.wantsSystem
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // Nothing reads the histories while no system widget is placed, and keeping a month of old samples for
    // the next card to inherit would draw a graph of a time nobody was looking
    onWantsSystemChanged: {
        if (!root.wantsSystem)
            root.clearSystem();
    }

    // --- Network speeds ---
    readonly property bool wantsNetwork: root.widgetConfig.enabled && root.entries.some(e => e.enabled && e.id === "network")

    property real down
    property real up
    property var downHistory: []
    property var upHistory: []

    // Speeds are not percentages, so these histories keep the raw bytes a second and the card scales them
    // against its own busiest reading
    function pushSpeed(history: var, value: real): var {
        const next = history.concat([Math.max(0, value)]);
        return next.length > 24 ? next.slice(next.length - 24) : next;
    }

    function sampleNetwork(): void {
        root.down = NetworkUsage.downloadSpeed ?? 0;
        root.up = NetworkUsage.uploadSpeed ?? 0;
        root.downHistory = root.pushSpeed(root.downHistory, root.down);
        root.upHistory = root.pushSpeed(root.upHistory, root.up);
    }

    ServiceRef {
        service: root.wantsNetwork ? NetworkUsage : null
    }

    Timer {
        interval: root.sampleInterval
        running: root.wantsNetwork
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleNetwork()
    }

    onWantsNetworkChanged: {
        if (!root.wantsNetwork) {
            root.downHistory = [];
            root.upHistory = [];
        }
    }

    // --- GitHub contributions ---
    // How long a fetched calendar is good for. A card that comes back after this re-asks while still showing
    // the days it has, rather than blanking first and filling in when the reply lands
    readonly property int githubTtl: 900000

    // user -> { days, fetched }, and the last failure per user, so an empty card can say why
    property var github: ({})
    property var githubErrors: ({})

    function validGithubUser(name: string): bool {
        // Letters, digits and hyphens only: the name is part of a URL, so nothing else gets through
        return /^[A-Za-z0-9-]+$/.test(name);
    }

    function daysFor(name: string): var {
        return root.github[name]?.days ?? [];
    }

    function errorFor(name: string): string {
        return root.githubErrors[name] ?? "";
    }

    // The variants that show stars and followers ask for the profile as well as the calendar
    readonly property bool wantsGithubStats: root.widgetConfig.enabled && root.entries.some(e => e.enabled && e.id === "github" && (e.type ?? "").endsWith("-stats"))

    // Called by the background as the shell starts, which is what brings this cache into existence: the
    // readings then tick and the calendar is fetched while the desktop is still under windows, so the first
    // bare workspace shows filled-in cards instead of waiting for them to load
    function prime(): void {
        const user = root.widgetConfig.githubUser.trim();

        if (root.wantsGithub)
            root.requestGithub(user, false);
        if (root.wantsGithubStats)
            root.requestGithubStats(user, false);
    }

    // A card added to the layout fetches on its own, but the layout can reach the cache before the config has
    // been read, so the first moment there is something to fetch for is taken here as well
    onWantsGithubChanged: root.prime()
    onWantsGithubStatsChanged: root.prime()

    // Asks for a name's calendar unless a recent one is already here. `force` re-asks regardless, for the
    // day turning over or a name being retyped
    function requestGithub(name: string, force: bool): void {
        if (!root.validGithubUser(name))
            return;

        const cached = root.github[name];
        if (!force && cached && Date.now() - cached.fetched < root.githubTtl)
            return;
        // The same name is already on its way; a second curl would only race the first
        if (ghFetch.running && ghFetch.user === name)
            return;

        // A changed command is only picked up by a fresh run
        ghFetch.running = false;
        ghFetch.user = name;
        ghFetch.command = ["sh", "-c", `curl -fsSL --max-time 20 "https://github-contributions-api.jogruber.de/v4/${name}?y=last"`];
        ghFetch.running = true;
    }

    function storeGithub(name: string, days: var): void {
        const github = Object.assign({}, root.github);
        github[name] = {
            days: days,
            fetched: Date.now()
        };
        root.github = github;

        const errors = Object.assign({}, root.githubErrors);
        delete errors[name];
        root.githubErrors = errors;
    }

    function failGithub(name: string, why: string): void {
        const errors = Object.assign({}, root.githubErrors);
        errors[name] = why;
        root.githubErrors = errors;
    }

    // The last 30 days, oldest first. Worked out when the reply arrives rather than once at startup, so a
    // calendar fetched before midnight is not stored against yesterday's dates
    function lastThirtyDays(): var {
        const now = new Date();

        return Array.from({
            length: 30
        }, (_, i) => {
            const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (29 - i));
            const month = String(day.getMonth() + 1).padStart(2, "0");
            const date = String(day.getDate()).padStart(2, "0");
            return `${day.getFullYear()}-${month}-${date}`;
        });
    }

    // The calendar as JSON rather than as GitHub's page: the page's markup moves, this shape does not, and it
    // carries the counts outright
    function parseGithub(name: string, json: string): void {
        // A cancelled run finishes with nothing to read, which is not a failed fetch
        if (json.trim() === "")
            return;

        let data;
        try {
            data = JSON.parse(json);
        } catch (e) {
            root.failGithub(name, Tr.tr("Could not read the contributions data"));
            console.warn(lc, `Contributions: unreadable response: ${e}`);
            return;
        }

        const list = Array.isArray(data?.contributions) ? data.contributions : [];
        if (list.length === 0) {
            root.failGithub(name, Tr.tr("No contributions came back for this name"));
            return;
        }

        const byDate = {};
        for (const day of list)
            byDate[day.date] = day;

        root.storeGithub(name, root.lastThirtyDays().map(date => ({
                    date: date,
                    count: byDate[date]?.count ?? 0,
                    level: byDate[date]?.level ?? 0
                })));
    }

    Process {
        id: ghFetch

        // The name this run is for, so a reply is filed under the right user even if the name changed while
        // the request was out
        property string user

        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.parseGithub(ghFetch.user, text)
        }

        // curl's own complaint, so a failed fetch says why on the card instead of going quiet
        stderr: StdioCollector {
            onStreamFinished: {
                const complaint = text.trim();
                if (complaint !== "")
                    root.failGithub(ghFetch.user, complaint);
            }
        }
    }

    // --- GitHub profile ---
    // Stars earned and followers, for the variants that show them. Both come back from one run, so they are
    // stored together and a card never shows one name's stars beside another's followers
    property var githubStats: ({})
    property var githubStatsErrors: ({})

    function statsFor(name: string): var {
        return root.githubStats[name] ?? null;
    }

    function statsErrorFor(name: string): string {
        return root.githubStatsErrors[name] ?? "";
    }

    function requestGithubStats(name: string, force: bool): void {
        if (!root.validGithubUser(name))
            return;

        const cached = root.githubStats[name];
        if (!force && cached && Date.now() - cached.fetched < root.githubTtl)
            return;
        if (ghStats.running && ghStats.user === name)
            return;

        // The profile and the repositories are two requests. They are joined into one stream with a line of
        // their own between them rather than run as two processes, which would arrive out of order and need
        // the two halves patched together afterwards
        ghStats.running = false;
        ghStats.user = name;
        ghStats.command = ["sh", "-c", `curl -fsSL --max-time 20 "https://api.github.com/users/${name}" && printf '\\n@@\\n' && curl -fsSL --max-time 20 "https://api.github.com/users/${name}/repos?per_page=100"`];
        ghStats.running = true;
    }

    function parseGithubStats(name: string, out: string): void {
        const parts = out.split("\n@@\n");
        if (parts.length < 2)
            return;

        let profile;
        let repos;
        try {
            profile = JSON.parse(parts[0]);
            repos = JSON.parse(parts[1]);
        } catch (e) {
            root.failGithubStats(name, Tr.tr("Could not read the profile data"));
            console.warn(lc, `Contributions: unreadable profile response: ${e}`);
            return;
        }

        // GitHub answers a name it does not know, or a rate-limited request, with an error object rather
        // than a list; that is a failure to say out loud, not a profile with nothing on it
        if (profile?.message || !Array.isArray(repos)) {
            root.failGithubStats(name, profile?.message ?? Tr.tr("No profile came back for this name"));
            return;
        }

        // Forks included, as GitHub counts them on a profile. Only the first hundred repositories are read,
        // which is every repository most people have
        const list = repos;
        const stars = list.reduce((sum, repo) => sum + (repo.stargazers_count ?? 0), 0);

        const next = Object.assign({}, root.githubStats);
        next[name] = {
            stars: stars,
            followers: profile.followers ?? 0,
            fetched: Date.now()
        };
        root.githubStats = next;

        const errors = Object.assign({}, root.githubStatsErrors);
        delete errors[name];
        root.githubStatsErrors = errors;
    }

    function failGithubStats(name: string, why: string): void {
        const errors = Object.assign({}, root.githubStatsErrors);
        errors[name] = why;
        root.githubStatsErrors = errors;
    }

    Process {
        id: ghStats

        property string user

        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.parseGithubStats(ghStats.user, text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const complaint = text.trim();
                if (complaint !== "")
                    root.failGithubStats(ghStats.user, complaint);
            }
        }
    }

    // --- Package count ---
    // -1 until counted. The count only changes when something is installed, so one answer per session is
    // enough and the fetch card doesn't pay for pacman again every time it is rebuilt
    property int packageCount: -1

    function ensurePackages(): void {
        if (root.packageCount >= 0 || packages.running)
            return;

        packages.running = true;
    }

    Process {
        id: packages

        running: false
        command: ["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"]

        stdout: StdioCollector {
            onStreamFinished: root.packageCount = parseInt(text) || 0
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.widgetdata"
        defaultLogLevel: LoggingCategory.Warning
    }
}
