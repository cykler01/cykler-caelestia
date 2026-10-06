import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components.misc
import qs.services

// An ambient clock, not a lock - triggered by a keybind on whichever monitor has focus at the
// time (see StandbyWindow.qml for the actual per-screen window), and dismissed by any input.
Scope {
    id: root

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

    function toggle(): void {
        const screen = root.focusedScreen();
        if (!screen)
            return;

        const state = ShellState.forScreen(screen);
        if (state.standby) {
            state.standby = false;
            return;
        }

        // Only one screen stands by at a time - toggling it on a second monitor without
        // clearing the first would leave that one stuck showing the clock indefinitely
        root.dismiss();
        state.standby = true;
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "standby"
        description: "Toggle the standby clock on the focused screen"
        onPressed: root.toggle()
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
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
