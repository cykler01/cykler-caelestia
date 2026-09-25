pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// Drives the Update page: checks the repo this shell is built from for new commits on the tracked branch, and can
// pull, rebuild, install (through pkexec) and restart the shell, using scripts/shell-update.sh in that checkout.
Singleton {
    id: root

    readonly property string repoPath: GlobalConfig.services.repoPath || `${Paths.home}/Documents/Github/cykler-caelestia`
    readonly property string branch: GlobalConfig.services.updateBranch || "main"
    readonly property string script: `${repoPath}/scripts/shell-update.sh`

    // "idle" | "checking" | "installing" | "done" | "error"
    property string state: "idle"
    property string errorText
    property string currentStep
    property string head
    property string localBranch
    property bool dirty
    property int behind
    property list<string> commits: []
    property list<string> log: []
    property list<string> warnings: []
    property bool checked

    readonly property bool busy: state === "checking" || state === "installing"

    function reset(): void {
        errorText = "";
        commits = [];
        log = [];
        warnings = [];
    }

    // stash: pass true to stash uncommitted changes, pull, and restore them afterwards
    function install(stash: bool): void {
        if (busy)
            return;

        reset();
        state = "installing";
        currentStep = "";
        installProc.command = ["bash", script, "install", repoPath, branch, stash ? "stash" : "no"];
        installProc.running = true;
    }

    function check(): void {
        if (busy)
            return;

        reset();
        state = "checking";
        const found = [];
        checkProc.found = found;
        checkProc.command = ["bash", script, "check", repoPath, branch];
        checkProc.running = true;
    }

    // Restart the shell so it loads what was just installed; detached so it survives the shell it is restarting
    function restart(): void {
        Quickshell.execDetached(["caelestia", "shell", "-r"]);
    }

    Process {
        id: checkProc

        property var found: []

        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(":");
                const key = line.slice(0, i);
                const value = line.slice(i + 1);
                if (key === "HEAD")
                    root.head = value;
                else if (key === "BRANCH")
                    root.localBranch = value;
                else if (key === "DIRTY")
                    root.dirty = value === "1";
                else if (key === "BEHIND")
                    root.behind = parseInt(value) || 0;
                else if (key === "LOG")
                    checkProc.found.push(value);
                else if (key === "ERROR")
                    root.errorText = value;
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.state = "error";
                if (!root.errorText)
                    root.errorText = Tr.tr("The check failed. Is the repository path right?");
                return;
            }
            root.commits = found;
            root.checked = true;
            root.state = "idle";
        }
    }

    Process {
        id: installProc

        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(":");
                const key = line.slice(0, i);
                const value = line.slice(i + 1);
                if (key === "STEP")
                    root.currentStep = value;
                else if (key === "LOG")
                    root.log = [...root.log, value].slice(-12);
                else if (key === "WARN")
                    root.warnings = [...root.warnings, value];
                else if (key === "ERROR")
                    root.errorText = value;
                else if (line === "DONE")
                    root.currentStep = "done";
            }
        }

        onExited: (code, status) => {
            if (code === 0 && root.currentStep === "done") {
                root.state = "done";
                // Give the page a moment to say so before the shell goes away
                restartTimer.start();
            } else {
                root.state = "error";
                if (!root.errorText)
                    root.errorText = Tr.tr("The update did not finish.");
            }
        }
    }

    Timer {
        id: restartTimer

        interval: 2500
        onTriggered: root.restart()
    }
}
