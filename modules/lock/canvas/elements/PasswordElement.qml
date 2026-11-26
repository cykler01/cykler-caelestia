pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.center
import qs.modules.lock.layouts

// The password field, the one element every lock screen has. An optional prompt sits before it
// ("Password:", for a console look), and the wrong-password and other PAM messages hang under it
// without taking room of their own
FocusScope {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null

    readonly property real fieldWidth: (root.opts.width ?? 340) * root.s

    // A focus scope only passes the keyboard down if it asks for it itself, so without this the
    // field inside never had it until it was clicked
    focus: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: Tokens.spacing.large * root.s

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: (root.opts.label ?? "") !== ""
            text: root.opts.label ?? ""
            color: Colours.palette.m3onSurface
            font: Tokens.font.mono.builders.medium.scale(root.s * 1.15).weight(Font.Bold).build()
        }

        PasswordField {
            Layout.preferredWidth: root.fieldWidth
            Layout.alignment: Qt.AlignVCenter
            focus: true
            lock: root.lock
            uiScale: root.s
            fieldWidth: root.fieldWidth
        }
    }

    Loader {
        anchors.top: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        active: !!root.lock && (root.opts.messages ?? true)

        sourceComponent: StateMessage {
            pam: root.lock.pam
        }
    }
}
