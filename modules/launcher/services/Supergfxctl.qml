pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

Searcher {
    id: root

    property var modeData: []
    property int modeRevision
    property string requestedMode
    property int lastExitCode
    property string lastError
    readonly property list<string> fallbackModes: ["Integrated", "Hybrid", "AsusMuxDgpu"]

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}gpu `.length);
    }

    function reload(): void {
        getModes.running = false;
        root.modeData = root.fallbackModes.map(root.createMode);
        root.modeRevision++;
        getModes.running = true;
    }

    function createMode(mode: string): var {
        return {
            name: mode,
            desc: Tr.tr("Switch to %1 graphics mode").arg(mode),
            icon: "developer_board",
            onClicked: list => {
                list.screenState.launcher = false;
                root.requestedMode = mode;
                setMode.command = ["supergfxctl", "--mode", mode];
                setMode.running = true;
            }
        };
    }

    function notify(summary: string, body: string, icon: string, urgency: string): void {
        Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-i", icon, "-u", urgency, summary, body]);
    }

    function notifyWithRestart(summary: string, body: string): void {
        // The summary and body are passed as arguments so that translations are never parsed by bash
        Quickshell.execDetached(["bash", "-c", "action=$(notify-send --app-name=caelestia-shell --wait --icon=system-reboot --action=\"restart=$3\" \"$1\" \"$2\"); [ \"$action\" = restart ] && systemctl reboot", "bash", summary, body, Tr.tr("Restart now")]);
    }

    function reportModeChange(exitCode: int, errorText: string, action: string): void {
        // The mode change can be accepted and still fail to apply until the session ends, so a pending
        // action counts as a success, while an unknown one (no --pend-action support) assumes a restart
        if (exitCode !== 0 && !/reboot|logout/i.test(action)) {
            root.notify(Tr.tr("Failed to change GPU mode"), errorText.trim() || Tr.tr("supergfxctl exited with code %1").arg(exitCode), "dialog-error", "critical");
            return;
        }

        if (/logout/i.test(action))
            root.notifyWithRestart(Tr.tr("GPU mode changed"), Tr.tr("Log out for the new graphics mode to take effect."));
        else if (action === "unknown" || /reboot/i.test(action))
            root.notifyWithRestart(Tr.tr("GPU mode changed"), Tr.tr("Restart the computer for the new graphics mode to take effect."));
        else
            root.notifyWithRestart(Tr.tr("GPU mode changed"), Tr.tr("Switched to %1 graphics mode").arg(root.requestedMode));
    }

    function canonicalMode(mode: string): string {
        const lower = mode.toLowerCase();
        const knownModes = {
            integrated: "Integrated",
            hybrid: "Hybrid",
            vfio: "Vfio",
            asusegpu: "AsusEgpu",
            asusmuxdgpu: "AsusMuxDgpu",
            compute: "Compute",
            dedicated: "Dedicated"
        };
        return knownModes[lower] ?? "";
    }

    function updateModes(output: string): void {
        const modes = [];
        const matches = output.match(/Integrated|Hybrid|VFIO|Vfio|AsusEgpu|AsusMuxDgpu|Compute|Dedicated/gi) ?? [];
        for (const match of matches) {
            const mode = root.canonicalMode(match);
            if (mode && !modes.includes(mode))
                modes.push(mode);
        }

        if (modes.length === 0)
            return;

        root.modeData = modes.map(root.createMode);
        root.modeRevision++;
    }

    list: root.modeData
    useFuzzy: false

    Component.onCompleted: root.reload()

    Connections {
        function onEnableSupergfxctlChanged(): void {
            root.reload();
        }

        target: Config.launcher
    }

    Process {
        id: getModes

        command: ["supergfxctl", "-s"]
        stdout: StdioCollector {
            onStreamFinished: root.updateModes(text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn(`supergfxctl exited with code ${exitCode}`);
        }
    }

    Process {
        id: setMode

        stderr: StdioCollector {
            id: setModeError
        }
        onExited: exitCode => {
            root.lastExitCode = exitCode;
            root.lastError = setModeError.text;
            pendingAction.running = true;
        }
    }

    Process {
        id: pendingAction

        command: ["supergfxctl", "--pend-action"]
        stdout: StdioCollector {
            id: pendingActionOutput
        }
        onExited: exitCode => root.reportModeChange(root.lastExitCode, root.lastError, exitCode === 0 ? pendingActionOutput.text.trim() : "unknown")
    }
}
