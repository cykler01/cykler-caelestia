pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.lock.center as LockCenter
import qs.services

// One of these per connected screen (see Standby.qml) - only ever visible on whichever screen
// had focus when the standby keybind was pressed, via its own ScreenState.standby.
StyledWindow {
    id: root

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    readonly property bool open: root.screenState?.standby ?? false

    function dismiss(): void {
        if (root.screenState)
            root.screenState.standby = false;
    }

    name: "standby"
    visible: root.open
    implicitWidth: screen?.width ?? 0
    implicitHeight: screen?.height ?? 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Rectangle {
        anchors.fill: parent
        color: "black"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPositionChanged: root.dismiss()
            onPressed: root.dismiss()
        }

        Item {
            anchors.centerIn: parent
            implicitWidth: clock.implicitWidth
            implicitHeight: clock.implicitHeight + (date.visible ? date.implicitHeight + Tokens.spacing.large : 0)

            focus: root.open
            Keys.onPressed: event => {
                event.accepted = true;
                root.dismiss();
            }

            LockCenter.Clock {
                id: clock

                anchors.horizontalCenter: parent.horizontalCenter
                centerScale: 1
            }

            StyledText {
                id: date

                anchors.top: clock.bottom
                anchors.topMargin: Tokens.spacing.large
                anchors.horizontalCenter: parent.horizontalCenter
                visible: GlobalConfig.general.standby.showDate
                text: Time.format("dddd • d MMM").toUpperCase()
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.headline.small
            }
        }
    }
}
