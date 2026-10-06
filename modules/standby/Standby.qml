pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.misc
import qs.modules.lock.center as LockCenter
import qs.services

// An ambient clock for one screen, not a lock - no PAM, no session lock, just something to
// look at instead of a dark/idle monitor. Shown while GlobalConfig.general.standby.screen names
// a connected screen and that screen's ScreenState.standby is set (toggled by the "standby" /
// "unstandby" idle actions in IdleMonitors.qml), and dismissed by any input.
StyledWindow {
    id: root

    readonly property ShellScreen targetScreen: Quickshell.screens.find(s => s.name === GlobalConfig.general.standby.screen) ?? null
    readonly property ScreenState screenState: root.targetScreen ? ShellState.forScreen(root.targetScreen) : null
    readonly property bool open: root.screenState?.standby ?? false

    function dismiss(): void {
        if (root.screenState)
            root.screenState.standby = false;
    }

    // Named to avoid colliding with Window's own show()
    function activate(): void {
        if (root.screenState)
            root.screenState.standby = true;
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "standby"
        description: "Show the standby clock on its configured screen"
        onPressed: root.open ? root.dismiss() : root.activate()
    }

    IpcHandler {
        function show(): void {
            root.activate();
        }

        function dismiss(): void {
            root.dismiss();
        }

        target: "standby"
    }

    name: "standby"
    screen: root.targetScreen
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
