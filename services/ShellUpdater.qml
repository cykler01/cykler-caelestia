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
    // Commit dates as ISO strings: the commit this checkout is on, and the newest one on the tracked
    // branch. Shown by the Update page as the age of this build against the newest one available.
    property string currentDate
    property string latestDate
    property bool dirty
    property int behind
    property list<string> commits: []
    property list<string> log: []
    property list<string> warnings: []
    property bool checked

    // Branches available on origin, offered by the Update page's branch picker
    property list<string> branches: []
    property bool branchesLoading

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
        fetchBranches();
    }

    // Refresh the list of branches offered by the Update page's picker
    function fetchBranches(): void {
        if (branchesProc.running)
            return;

        branchesLoading = true;
        const found = [];
        branchesProc.found = found;
        branchesProc.command = ["bash", script, "branches", repoPath];
        branchesProc.running = true;
    }

    // Restart the shell so it loads what was just installed; detached so it survives the shell it is restarting
    function restart(): void {
        Quickshell.execDetached(["caelestia", "shell", "-r"]);
    }

    // Unload the shell; detached so it survives the shell it is stopping
    function kill(): void {
        Quickshell.execDetached(["caelestia", "shell", "-k"]);
    }

    // Unload the shell, start it again and open Nexus back on `page` (a PageRegistry key). The reopen is
    // retried because a fresh instance registers its IPC handlers a moment after it starts.
    function restartAndReopen(page: string): void {
        Quickshell.execDetached([
            "sh",
            "-c",
            `caelestia shell -k && sleep 1 && caelestia shell -d && { i=0; while [ "$i" -lt 30 ]; do caelestia shell nexus openPage ${page} >/dev/null 2>&1 && break; i=$((i + 1)); sleep 0.5; done; }`
        ]);
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
                else if (key === "CURRENT")
                    root.currentDate = value;
                else if (key === "LATEST")
                    root.latestDate = value;
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
        id: branchesProc

        property var found: []

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("BRANCH:"))
                    branchesProc.found.push(line.slice(7));
            }
        }

        onExited: (code, status) => {
            root.branches = branchesProc.found;
            root.branchesLoading = false;
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
