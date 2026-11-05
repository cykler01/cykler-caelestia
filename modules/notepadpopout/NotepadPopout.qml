import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The notepad's own IPC target: `qs -c caelestia ipc call notepad open|close|toggle`, or the
// `caelestia:notepadPopout` global shortcut. The notepad itself is a tab of the sidebar (see
// modules/notifpopout/Content.qml, modules/notepadpopout/Content.qml) rather than a panel of its
// own, so this just points the shared sidebar/notifPopoutTabKey state at it. Does nothing while
// the tab is turned off in the settings.
Scope {
    id: root

    function setActive(open: bool): void {
        const state = ShellState.forActive();
        if (!state)
            return;

        if (open) {
            if (!SidebarTabs.isEnabled("notes"))
                return;
            state.notifPopoutTabKey = "notes";
        }
        state.sidebar = open;
    }

    function toggle(): void {
        const state = ShellState.forActive();
        if (state)
            root.setActive(!(state.sidebar && state.notifPopoutTabKey === "notes"));
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

        target: "notepad"
    }
}
