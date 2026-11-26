pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.containers
import qs.services

// NOTE(fork): the lock screen layout editor, a full-screen overlay on the focused screen with the
// lock screen drawn at its real size, to arrange it the way desktop widgets are arranged: drag
// things about, pull a corner to resize, add, restyle and remove them (EditorSurface.qml). Opened
// from Nexus > Lock screen > Edit layout through ShellState.lockEditorOpen
Scope {
    LazyLoader {
        active: ShellState.lockEditorOpen

        StyledWindow {
            id: win

            // Whichever screen has focus when it opens, kept for as long as it's open
            screen: Screens.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Screens.screens[0] ?? null
            name: "lock-editor"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            color: "black"

            EditorSurface {
                anchors.fill: parent
                focus: true
                onClosed: ShellState.lockEditorOpen = false
            }
        }
    }
}
