pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.utils

// Queries and installs OS & ecosystem updates via scripts/caelestia-updater.py, leaving
// shell git/CMake updates to ShellUpdater so there is only one place updating the shell.
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("scripts/caelestia-updater.py")

    property string state: "idle"
    property string currentStep
    property string errorText
    property string warningText
    property bool checked
    property bool canCheck: true

    property int cachyCount
    property var cachyItems: []
    property int hyprCount
    property var hyprItems: []
    property int caelestiaCount
    property var caelestiaItems: []
    property var history: []
    property list<string> log: []

    readonly property int totalUpdates: cachyCount + hyprCount + caelestiaCount
    readonly property bool busy: state === "checking" || state === "updating" || state === "rolling_back"

    function check(): void {
        if (busy)
            return;
        state = "checking";
        errorText = "";
        statusProc.buf = "";
        statusProc.errBuf = "";
        statusProc.command = ["python3", scriptPath, "status"];
        statusProc.running = true;
    }

    function update(target: string): void {
        if (busy)
            return;
        state = "updating";
        currentStep = "";
        errorText = "";
        warningText = "";
        log = [];
        actionProc.command = ["python3", scriptPath, "update", target, ShellUpdater.repoPath];
        actionProc.running = true;
    }

    function rollback(entryId: string): void {
        if (busy)
            return;
        state = "rolling_back";
        currentStep = "";
        errorText = "";
        warningText = "";
        log = [];
        actionProc.command = ["python3", scriptPath, "rollback", entryId];
        actionProc.running = true;
    }

    Process {
        id: statusProc

        property string buf: ""
        property string errBuf: ""

        stdout: SplitParser {
            onRead: line => statusProc.buf += line
        }

        stderr: SplitParser {
            onRead: line => statusProc.errBuf += (statusProc.errBuf ? " " : "") + line
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.state = "error";
                root.canCheck = false;
                root.errorText = statusProc.errBuf || Tr.tr("Failed to query system updates (exit code %1)").arg(code);
                return;
            }
            try {
                const data = JSON.parse(statusProc.buf);
                root.canCheck = data.can_check ?? true;
                root.cachyCount = data.cachyos?.count ?? 0;
                root.cachyItems = data.cachyos?.items ?? [];
                root.hyprCount = data.hyprland?.count ?? 0;
                root.hyprItems = data.hyprland?.items ?? [];
                root.caelestiaCount = data.caelestia?.count ?? 0;
                root.caelestiaItems = data.caelestia?.items ?? [];
                root.history = data.history ?? [];
                root.checked = true;
                if (!root.canCheck) {
                    root.state = "error";
                    root.errorText = data.check_error || Tr.tr("Unable to query pending package updates");
                } else {
                    root.state = "idle";
                }
            } catch (e) {
                root.state = "error";
                root.canCheck = false;
                root.errorText = Tr.tr("Invalid updater response: %1").arg(e);
            }
        }
    }

    Process {
        id: actionProc

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("STEP:"))
                    root.currentStep = line.slice(5);
                else if (line.startsWith("LOG:"))
                    root.log = [...root.log, line.slice(4)].slice(-10);
                else if (line.startsWith("WARN:"))
                    root.warningText = line.slice(5);
                else if (line.startsWith("ERROR:"))
                    root.errorText = line.slice(6);
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.state = "error";
                if (!root.errorText)
                    root.errorText = root.log.length > 0 ? root.log[root.log.length - 1] : Tr.tr("Updater exited with code %1").arg(code);
                return;
            }
            root.state = "done";
            root.check();
        }
    }
}
