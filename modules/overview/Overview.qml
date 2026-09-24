import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Overview of all workspaces and their windows, opened by a 4-finger swipe up
// or the top-left hot corner. See ShellState.overview.
Scope {
    id: root

    function setActive(open: bool): void {
        const state = ShellState.forActive();
        if (state)
            state.overview = open;
    }

    function toggle(): void {
        const state = ShellState.forActive();
        if (state)
            state.overview = !state.overview;
    }

    IpcHandler {
        function open(): void {
            root.setActive(true);
        }

        function close(): void {
            root.setActive(false);
        }

        function toggle(): void {
            root.toggle();
        }

        target: "overview"
    }

    Variants {
        model: Screens.screens

        OverviewWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }
}
