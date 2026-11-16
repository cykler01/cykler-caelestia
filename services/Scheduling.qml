pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// NOTE(fork): drives the Plugins page. The stock ananicy rulesets classify "qs" as a background
// Service - nice 10 - which is fair for a bar but not for a whole desktop shell, and it shows up
// as dropped frames whenever anything else wants the CPU. scheduling/install-rules.sh puts a rule
// in /etc/ananicy.d that outranks it; this reads the state back and runs the script through pkexec.
Singleton {
    id: root

    readonly property string repoPath: GlobalConfig.services.repoPath || `${Paths.home}/Documents/Github/cykler-caelestia`
    readonly property string script: `${repoPath}/scheduling/install-rules.sh`

    // The ananicy unit found on this system, empty where none is installed
    property string service
    property bool serviceActive
    property bool ruleInstalled
    // What the shell is running at now, and what the rule asks for
    property int nice
    property int targetNice: -6
    // Another file in /etc/ananicy.d that also names "qs" and may win over ours
    property string conflict
    property bool checked

    // "idle" | "checking" | "working" | "error"
    property string state: "idle"
    property string errorText
    property list<string> log: []

    readonly property bool busy: state === "checking" || state === "working"
    // Nothing renices the shell without ananicy, so there is nothing for the fix to undo
    readonly property bool available: service !== ""
    // Landed only when the rule is in place *and* the running shell actually carries it: ananicy
    // never revisits a process it has already classified, so the two can disagree until a restart
    readonly property bool applied: ruleInstalled && nice <= targetNice
    readonly property bool pendingRestart: ruleInstalled && nice > targetNice

    function refresh(): void {
        if (state === "working")
            return;

        state = "checking";
        statusProc.command = ["bash", script, "--status", String(Quickshell.processId)];
        statusProc.running = true;
    }

    function apply(): void {
        run([]);
    }

    function remove(): void {
        run(["--remove"]);
    }

    // pkexec puts up the shell's own polkit prompt; a cancelled prompt exits non-zero and is not
    // worth an error banner, so it falls back to a plain refresh
    function run(args: list<string>): void {
        if (busy)
            return;

        errorText = "";
        log = [];
        state = "working";
        actionProc.command = ["pkexec", script, ...args];
        actionProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: statusProc

        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("=");
                if (i < 0)
                    return;

                const key = line.slice(0, i);
                const value = line.slice(i + 1);
                if (key === "service")
                    root.service = value;
                else if (key === "active")
                    root.serviceActive = value === "1";
                else if (key === "rule")
                    root.ruleInstalled = value === "1";
                else if (key === "nice")
                    root.nice = parseInt(value) || 0;
                else if (key === "target")
                    root.targetNice = parseInt(value) || -6;
                else if (key === "conflict")
                    root.conflict = value;
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.state = "error";
                root.errorText = Tr.tr("Could not read the scheduling state. Is the repository path right?");
                return;
            }
            root.checked = true;
            root.state = "idle";
        }
    }

    Process {
        id: actionProc

        stdout: SplitParser {
            onRead: line => root.log = [...root.log, line].slice(-12)
        }

        onExited: code => {
            // 126 and 127 are pkexec's own: the prompt was dismissed, or it could not start
            if (code !== 0 && code !== 126 && code !== 127)
                root.errorText = Tr.tr("The change did not go through.");
            root.state = "idle";
            root.refresh();
        }
    }
}
