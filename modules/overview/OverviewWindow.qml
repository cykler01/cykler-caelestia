pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Full-screen overlay (namespace caelestia-overview) showing every workspace as a
// column of window previews. Its own layer window so it can sit above everything and
// take keyboard focus, unlike the shared drawers window.
StyledWindow {
    id: root

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    // Attached config lives on the content item, the same as every other window here
    readonly property bool open: (screenState?.overview ?? false) && (contentItem?.Config.overview.enabled ?? false)
    readonly property bool wanted: open || reveal > 0 || lift > 0

    // 0 when closed, 1 when fully open; drives the enter/leave animation. reveal fades the
    // scrim and grid in, lift is how far the grid has been pulled up from below the screen
    property real reveal: open ? 1 : 0
    property real lift: open ? 1 : 0

    name: "overview"
    visible: wanted
    implicitWidth: screen.width
    implicitHeight: screen.height
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on reveal {
        Anim {
            type: Anim.FastEffects
        }
    }

    Behavior on lift {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    // The overview owns the screen while it is up, so nothing else stays open (or
    // competing for the keyboard) underneath it
    onOpenChanged: {
        if (open && screenState) {
            screenState.launcher = false;
            screenState.dashboard = false;
            screenState.session = false;
            screenState.sidebar = false;
            screenState.utilities = false;
        }
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: {
            if (root.screenState)
                root.screenState.overview = false;
        }
    }

    Content {
        id: content

        anchors.fill: parent
        screen: root.screen
        screenState: root.screenState
        reveal: root.reveal
        lift: root.lift
    }
}
