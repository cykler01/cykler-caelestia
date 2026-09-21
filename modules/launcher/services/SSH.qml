pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

Searcher {
    id: root

    readonly property string configPath: `${Paths.home}/.ssh/config`
    property var hostData: []
    property int hostRevision

    function transformSearch(search: string): string {
        const prefix = `${GlobalConfig.launcher.actionPrefix}ssh`;
        return search.startsWith(`${prefix} `) ? search.slice(`${prefix} `.length) : "";
    }

    function selector(item: var): string {
        return `${item.name} ${item.description}`;
    }

    function search(searchText: string): var {
        const prefix = `${GlobalConfig.launcher.actionPrefix}ssh`;
        const query = searchText.startsWith(`${prefix} `) ? searchText.slice(`${prefix} `.length).trim().toLowerCase() : "";
        if (!query)
            return root.hostData;

        return root.hostData.filter(host => host.name.toLowerCase().includes(query));
    }

    function reload(): void {
        readConfig.running = false;
        readConfig.running = true;
    }

    function connect(host: string, list: AppList): void {
        list.screenState.launcher = false;
        Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "ssh", host]);
    }

    function updateHosts(config: string): void {
        root.hostData = root.parseHosts(config);
        root.hostRevision++;
    }

    function parseHosts(config: string): var {
        const result = [];
        const seen = new Set();

        for (const line of config.split("\n")) {
            const match = line.match(/^\s*Host\s+(.+)$/i);
            if (!match)
                continue;

            const hostPatterns = match[1].split("#")[0].trim().split(/\s+/);
            for (const host of hostPatterns) {
                if (!host || host.includes("*") || host.includes("?") || host.startsWith("!"))
                    continue;
                if (seen.has(host))
                    continue;

                seen.add(host);
                result.push({
                    name: host,
                    description: Tr.tr("SSH host"),
                    icon: "terminal",
                    onClicked: list => root.connect(host, list)
                });
            }
        }

        return result.sort((a, b) => a.name.localeCompare(b.name));
    }

    list: root.hostData
    useFuzzy: false
    keys: ["name", "description"]
    weights: [0.8, 0.2]

    Process {
        id: readConfig

        command: ["cat", root.configPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateHosts(text)
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.hostData = [];
                root.hostRevision++;
            }
        }
    }
}
