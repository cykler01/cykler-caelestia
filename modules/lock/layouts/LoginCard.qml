pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.lock.center

// The login half of the centre card on its own: profile picture, username, password field and
// the PAM state line under it. framed puts it on a card of its own (split); without, it sits
// straight on whatever panel holds it (sidebar, minimal).
//
// lock is null in the settings page's preview, where a dummy field stands in for the real one -
// the real PasswordInput grabs keyboard focus and drives PAM, neither of which a preview may do
StyledRect {
    id: root

    required property var lock
    property real uiScale: 1
    property bool framed: true
    property bool showGreeting: false
    property real avatarSize: 110 * root.uiScale
    // A small avatar beside the username and password field instead of a large one above them,
    // for when vertical room matters more (sidebar)
    property bool inline: false

    readonly property real pad: framed ? Tokens.padding.extraLarge * root.uiScale : 0

    implicitWidth: 400 * root.uiScale
    implicitHeight: column.implicitHeight + root.pad * 2
    radius: Tokens.rounding.extraLarge * 1.5
    color: framed ? Colours.tPalette.m3surfaceContainer : "transparent"

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.pad
        spacing: Tokens.spacing.medium * root.uiScale

        ProfilePic {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.inline
            // ProfilePic sizes itself to 70% of the width it's given
            centerWidth: root.avatarSize / 0.7
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: column.width
            // The greeting already names the user
            visible: !root.showGreeting && !root.inline
            text: SysInfo.user
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
            elide: Text.ElideRight
        }

        Greeting {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showGreeting
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.inline ? 0 : Tokens.spacing.small * root.uiScale
            spacing: Tokens.spacing.large * root.uiScale

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: root.inline
                visible: active

                sourceComponent: ProfilePic {
                    centerWidth: root.avatarSize / 0.7
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.uiScale

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.small * root.uiScale
                    visible: root.inline && !root.showGreeting
                    text: SysInfo.user
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.medium.scale(root.uiScale).weight(Font.DemiBold).build()
                    elide: Text.ElideRight
                }

                Loader {
                    Layout.fillWidth: true
                    // A FocusScope: without focus here the field inside can never hold the keyboard
                    focus: true
                    sourceComponent: root.lock ? realInput : dummyInput
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            // The wrong-password and state lines hang below the field rather than reserving a
            // line of their own, so the card isn't left with dead space under the field. They
            // fall into the card's padding
            Layout.preferredHeight: 0
            Layout.maximumHeight: 0
            active: !!root.lock
            visible: active

            sourceComponent: StateMessage {
                pam: root.lock.pam
            }
        }
    }

    Component {
        id: realInput

        PasswordInput {
            centerScale: Math.max(0.8, root.uiScale)
            centerWidth: column.width / 0.8
            lock: root.lock
        }
    }

    Component {
        id: dummyInput

        StyledRect {
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
