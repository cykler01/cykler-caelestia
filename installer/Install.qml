pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// the run itself. runner.py owns the pty and outlives this window, so closing
// the installer mid-install does not kill it -- reopening picks the run back up
// from the same events file.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/cykler-install"
    readonly property string src: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/$/, "")

    // "" idle, else the phase the runner last reported
    property string phase: ""
    property string phaseText: ""
    property real progress: 0
    property bool authok: false
    property bool finished: false
    property int code: -1
    property string reason: ""
    property var warnings: []
    property bool cancelled: false

    // the question on screen, or null
    property var ask: null
    // the last line the pty drew but has not ended
    property string live: ""

    readonly property bool running: root.phase !== "" && !root.finished
    readonly property bool ok: root.finished && root.code === 0 && !root.cancelled

    property var log: []

    signal lineLogged(string text)

    function start(args: var): void {
        root.log = [];
        root.finished = false;
        root.cancelled = false;
        root.code = -1;
        root.reason = "";
        root.progress = 0;
        root.phase = "auth";
        root.phaseText = "Asking for your password";
        wipe.command = ["sh", "-c", "rm -rf \"$1\" && mkdir -p \"$1\"", "sh", root.dir];
        wipe.argsAfter = args;
        wipe.running = true;
    }

    function answer(value: string): void {
        if (!root.ask)
            return;
        const msg = JSON.stringify({
            "n": root.ask.n,
            "value": value
        });
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" >> \"$2\"", "sh", msg, root.dir + "/answers"]);
        root.ask = null;
    }

    function cancel(): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' '{\"cancel\":true}' >> \"$1\"", "sh", root.dir + "/answers"]);
    }

    // a fresh runtime dir first: a stale events file would replay last time's run
    Process {
        id: wipe

        property var argsAfter: []

        onExited: (code) => {
            if (code !== 0)
                return;
            events.path = root.dir + "/events.jsonl";
            runner.command = ["python3", "-I", Qt.resolvedUrl("runner.py").toString().replace("file://", ""), "--src", root.src, "--dir", root.dir].concat(wipe.argsAfter);
            runner.running = true;
        }
    }

    Process {
        id: runner
    }

    // one json object a line, appended as the install talks
    FileView {
        id: events

        property int seen: 0

        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            const lines = this.text().split("\n");
            for (let i = events.seen; i < lines.length; i++) {
                const raw = lines[i].trim();
                if (raw === "")
                    continue;
                try {
                    root.take(JSON.parse(raw));
                } catch (e) {
                }
            }
            events.seen = lines.length - 1;
        }
    }

    function take(ev: var): void {
        switch (ev.e) {
        case "phase":
            root.phase = ev.phase;
            root.phaseText = ev.text;
            root.progress = ev.p;
            break;
        case "progress":
            root.progress = ev.p;
            break;
        case "authok":
            root.authok = true;
            break;
        case "line":
            root.log = root.log.concat([ev.text]);
            root.lineLogged(ev.text);
            break;
        case "live":
            root.live = ev.text;
            break;
        case "ask":
            root.ask = ev;
            break;
        case "unask":
        case "answered":
            if (root.ask && root.ask.n === ev.n)
                root.ask = null;
            break;
        case "cancelled":
            root.cancelled = true;
            break;
        case "exit":
            root.finished = true;
            root.code = ev.code;
            root.reason = ev.reason || "";
            root.warnings = ev.warnings || [];
            root.live = "";
            root.ask = null;
            if (ev.code === 0 && !ev.cancelled)
                root.progress = 1;
            break;
        }
    }
}
