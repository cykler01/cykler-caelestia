pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

// Live preview of a single window, shown by the workspace window icons when the
// window actions are enabled. Sized by the popout it is loaded into.
Item {
    id: root

    required property var client

    implicitWidth: 320
    implicitHeight: 200

    ClipRect {
        anchors.fill: parent
        color: "transparent"
        radius: Tokens.rounding.large

        ScreencopyView {
            id: screencopy

            anchors.fill: parent
            captureSource: root.client?.wayland ?? null
            live: root.client !== null
            constraintSize: Qt.size(320, 200)
        }

        Loader {
            anchors.centerIn: parent
            active: !screencopy.hasContent

            sourceComponent: StyledText {
                text: Tr.tr("Preview unavailable")
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
