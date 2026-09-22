pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property int refCount: 0
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    // `caelestia record` spawns slurp (region captures) and gpu-screen-recorder,
    // which inherit the stdio of whoever ran it. A Process leaves its child's
    // channels attached to the shell's, so the recorder would keep writing to the
    // shell's stdout/stderr - and dies with SIGPIPE once the shell closes that pipe
    // - while slurp blocks on the shell's stdin until the shell exits. Redirect the
    // command's stdio to /dev/null so it and its children are detached from the
    // shell. The Process still tracks the command, so polling stays suppressed
    // while it runs.
    function runRecordCommand(args): void {
        commandProc.exec(["sh", "-c", 'exec "$@" </dev/null >/dev/null 2>&1', "sh", "caelestia", "record", ...args]);
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int

        reloadableId: "recorder"
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => { // qmllint disable signal-handler-parameters
            const running = code === 0;

            if (running && root.needsStop) {
                root.runRecordCommand([]);
                props.running = false;
                props.paused = false;
            } else if (running && root.needsPause) {
                root.runRecordCommand(["-p"]);
                props.paused = !props.paused;
            } else if (!running && root.needsStart) {
                root.runRecordCommand(root.startArgs);
                props.running = true;
                props.paused = false;
                props.elapsed = 0;
            } else if (running !== props.running && !commandProc.running) {
                // The recording was started/stopped outside the shell (e.g. via
                // keybind), or our command finished without reaching the optimistic state
                props.running = running;
                props.paused = false;
                props.elapsed = 0;
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    Process {
        id: commandProc

        // The command owns the transition: `caelestia record` blocks on slurp for
        // region captures, and waits for the recorder to finalise the file when
        // stopping. Reconcile once it has actually finished.
        onExited: checkProc.running = true // qmllint disable signal-handler-parameters
    }

    // Only poll while something is showing the state, i.e. the utilities drawer is open
    Timer {
        interval: 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: checkProc.running = true
    }

    Connections {
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        enabled: props.running && !props.paused
        target: Time // qmllint disable incompatible-type
    }
}
