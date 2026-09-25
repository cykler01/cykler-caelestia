pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.sidebar as Sidebar
import qs.services

// Its own layer window (namespace caelestia-notifpopout) so it can have blur
// rules and a blur strength different from the shared drawers window.
StyledWindow {
    id: root

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    readonly property bool open: screenState.notifPopout
    readonly property real gap: contentItem.Tokens.padding.large
    // Which side edge the popout opens from (config notifPopout.side, flipped by bar.mirrorPanels with a right-hand bar)
    readonly property bool mirrored: ShellState.componentsFor(screen)?.panels?.notifPopoutLeft ?? false
    // Separate from the sidebar's own so expanding cards in one doesn't affect the other
    readonly property var props: Sidebar.Props {
        reloadableId: "notifPopout"
    }

    property real offsetScale: open ? 0 : 1
    readonly property bool wanted: open || offsetScale < 1
    // The blur layer must be mapped first so it sits behind this window
    property bool mapped

    name: "notifpopout"
    visible: wanted && mapped
    implicitWidth: contentItem.Tokens.sizes.sidebar.width + gap
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // The media library tab has a search field, so that tab has to be able to take the
    // keyboard; the notification dock needs nothing beyond the mouse
    WlrLayershell.keyboardFocus: root.open && root.screenState.notifPopoutTab === 1 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: root.mirrored
    anchors.right: !root.mirrored

    mask: Region {
        item: panel
    }

    // Both live on the right edge, so only one can be open
    onOpenChanged: {
        if (open)
            screenState.sidebar = false;
    }

    onWantedChanged: {
        if (wanted) {
            mapDelay.restart();
        } else {
            mapDelay.stop();
            mapped = false;
        }
    }

    Behavior on offsetScale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Timer {
        id: mapDelay

        interval: 30
        onTriggered: root.mapped = true
    }

    // A second translucent layer behind the popout: the compositor blurs what is
    // behind each layer, so the popout ends up blurring an already blurred
    // backdrop. That is a stronger blur only here, unlike raising Hyprland's
    // global blur strength, which changes every window.
    StyledWindow {
        name: "notifpopout-blur"
        screen: root.screen
        visible: root.wanted
        implicitWidth: root.implicitWidth
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: root.mirrored
        anchors.right: !root.mirrored

        // No input, the popout above handles it
        mask: Region {}

        StyledRect {
            LayoutMirroring.enabled: root.mirrored
            LayoutMirroring.childrenInherit: true

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: panel.anchors.topMargin
            anchors.bottomMargin: panel.anchors.bottomMargin
            anchors.rightMargin: panel.anchors.rightMargin
            implicitWidth: panel.implicitWidth
            // Stays hidden until the popout above is mapped, so it never shows on its own
            opacity: root.mapped ? panel.opacity : 0

            radius: Tokens.rounding.extraLarge
            color: Qt.alpha(Colours.palette.m3surface, 0.25)
        }
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.screenState.notifPopout = false
    }

    Item {
        id: panel

        LayoutMirroring.enabled: root.mirrored
        LayoutMirroring.childrenInherit: true

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: root.gap
        anchors.bottomMargin: root.gap
        anchors.rightMargin: root.gap + (-width - root.gap) * root.offsetScale
        implicitWidth: Tokens.sizes.sidebar.width
        opacity: 1 - root.offsetScale

        Loader {
            anchors.fill: parent
            // Created up front so opening doesn't wait on building the notification list
            active: true

            sourceComponent: Content {
                // The content itself keeps its normal (unmirrored) layout
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true

                screenState: root.screenState
                props: root.props
            }
        }
    }
}
