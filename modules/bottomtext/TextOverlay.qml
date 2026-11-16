pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// NOTE(fork): a random line of text along the bottom of the screen (services/BottomText.qml).
//
// One window per monitor, on the bottom layer so windows pass over it, and with an empty input
// region so it never takes a click from the desktop underneath.
Variants {
    model: Screens.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData

        // Whatever the bar leaves along the bottom edge, so the text sits inside the frame. The global
        // config and tokens are read rather than the per-screen ones, which are not set up until after
        // the window's own bindings first run
        readonly property var bar: ShellState.componentsFor(win.screen)?.bar
        readonly property int bottomInset: (win.bar?.onBottom ? win.bar.contentThickness : GlobalConfig.border.thickness) + GlobalConfig.appearance.padding.medium

        screen: modelData
        name: "bottom-text"
        visible: GlobalConfig.utilities.bottomText.enabled
        implicitHeight: label.implicitHeight + GlobalConfig.appearance.padding.large * 2
        mask: empty

        margins.bottom: win.bottomInset
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        surfaceFormat.opaque: false

        Region {
            id: empty
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            width: parent.width - GlobalConfig.appearance.padding.extraLargeIncreased * 2
            text: BottomText.current
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
            font: Tokens.font.body.small
        }
    }
}
