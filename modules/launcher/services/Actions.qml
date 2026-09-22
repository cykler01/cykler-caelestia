pragma Singleton

import ".."
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.utils

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(GlobalConfig.launcher.actionPrefix.length);
    }

    list: variants.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: GlobalConfig.launcher.actions.filter(a => (a.enabled ?? true) && (GlobalConfig.launcher.enableDangerousActions || !(a.dangerous ?? false)) && (a.command?.[0] !== "autocomplete" || a.command?.[1] !== "gpu" || Config.launcher.enableSupergfxctl))

        Action {}
    }

    component Action: QtObject {
        required property var modelData
        readonly property string name: modelData.name ? Tr.trMarked(modelData.name) : Tr.trCtx("Unnamed", "launcher action with no name")
        readonly property string desc: modelData.description ? Tr.trMarked(modelData.description) : Tr.trCtx("No description", "launcher action with no description")
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property list<string> command: modelData.command ?? []
        readonly property bool enabled: modelData.enabled ?? true
        readonly property bool dangerous: modelData.dangerous ?? false

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${GlobalConfig.launcher.actionPrefix}${command[1]} `;
            } else if (["ocr", "lens"].includes(command[0])) {
                list.screenState.launcher = false;
                Quickshell.execDetached(["bash", `${Quickshell.shellDir}/assets/${command[0]}.sh`]);
            } else {
                list.screenState.launcher = false;
                if (!SessionManager.exec(command))
                    Quickshell.execDetached(command);
            }
        }
    }
}
