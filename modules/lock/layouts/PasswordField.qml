pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.center

// The password field on its own, for layouts that put it somewhere other than a LoginCard
// (console). lock is null in the settings page's preview, where a dummy pill stands in for the
// real field - the real PasswordInput grabs keyboard focus and drives PAM, neither of which a
// preview may do. A FocusScope, so the field inside can hold the keyboard
FocusScope {
    id: root

    required property var lock
    property real uiScale: 1
    // Room the field may grow to once there's something typed in it
    property real fieldWidth: 320 * uiScale

    // Asks for no width of its own: every caller stretches it across the room it has. Passing
    // the field's natural width up instead fed straight back into the layout sizing it, and a
    // fraction of a pixel's overflow was enough for the layout to squeeze it down to nothing
    implicitWidth: 0
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader

        anchors.left: parent.left
        anchors.right: parent.right
        focus: true
        sourceComponent: root.lock ? realInput : dummyInput
    }

    Component {
        id: realInput

        PasswordInput {
            centerScale: Math.max(0.8, root.uiScale)
            centerWidth: root.fieldWidth / 0.8
            lock: root.lock
        }
    }

    Component {
        id: dummyInput

        StyledRect {
            implicitWidth: root.fieldWidth
            implicitHeight: 48 * root.uiScale
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.large * root.uiScale
                anchors.rightMargin: Tokens.padding.large * root.uiScale
                spacing: Tokens.spacing.medium * root.uiScale

                MaterialIcon {
                    text: "lock"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.medium.scale(root.uiScale).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Password")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.builders.medium.scale(root.uiScale).build()
                }

                MaterialIcon {
                    text: "arrow_forward"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.medium.scale(root.uiScale).build()
                }
            }
        }
    }
}
