import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components.misc
import qs.services

// An ambient clock, not a lock - triggered by a keybind on whichever monitor has focus at the
// time (see StandbyWindow.qml for the actual per-screen window), dismissed by keyboard input
// only (not the mouse, which stays hidden and shouldn't need to move to get it back). Holding
// the keybind for a second instead shows it on every connected screen at once.
Scope {
    id: root

    readonly property bool anyOpen: Screens.screens.some(s => ShellState.forScreen(s).standby)

    function focusedScreen(): ShellScreen {
        // Hypr.focusedMonitor can sit stale until some other event nudges Hyprland's IPC
        // connection - forcing a refresh first is what every other place in this shell that
        // reads monitor state right before acting on it already does (see Hypr.qml)
        Hyprland.refreshMonitors();
        const name = Hypr.focusedMonitor?.name;
        return Screens.screens.find(s => s.name === name) ?? null;
    }

    function dismiss(): void {
        for (const screen of Screens.screens)
            ShellState.forScreen(screen).standby = false;
    }

    // Short press: the focused screen only, toggled off if anything at all is currently
    // showing (a second screen left standing by from the "all" mode otherwise has no way
    // to be dismissed with a single short press)
    function toggle(): void {
        if (root.anyOpen) {
            root.dismiss();
            return;
        }

        const screen = root.focusedScreen();
        if (screen)
            ShellState.forScreen(screen).standby = true;
    }

    function toggleAll(): void {
        if (root.anyOpen) {
            root.dismiss();
            return;
        }

        for (const screen of Screens.screens)
            ShellState.forScreen(screen).standby = true;
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        id: shortcut

        name: "standby"
        description: "Toggle the standby clock - hold for a second to show it on every screen"
        onPressed: holdTimer.restart()
        onReleased: {
            if (!holdTimer.running)
                return; // already handled as a hold, by the timer firing
            holdTimer.stop();
            root.toggle();
        }
    }

    Timer {
        id: holdTimer

        interval: 1000
        onTriggered: root.toggleAll()
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function toggleAll(): void {
            root.toggleAll();
        }

        function dismiss(): void {
            root.dismiss();
        }

        target: "standby"
    }

    Variants {
        model: Screens.screens

        StandbyWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }
}
