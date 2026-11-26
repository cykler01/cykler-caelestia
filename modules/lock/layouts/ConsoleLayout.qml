pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.lock.center

// After a getty login on a text console, and the terminal-window lock screens common in tiling
// window manager setups: one terminal window in the middle of the screen, everything in it in
// monospace - the issue line a console greets you with, a short fetch of the system, the date as
// if typed at a prompt, then a "Password:" prompt holding the real password field. The status
// pills and session actions keep to the corners
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale
    readonly property real pad: Tokens.padding.extraLarge * 1.25 * uiScale
    readonly property font mono: Tokens.font.mono.builders.medium.scale(uiScale * 1.15).build()
    readonly property font monoBold: Tokens.font.mono.builders.medium.scale(uiScale * 1.15).weight(Font.Bold).build()
    readonly property string host: SysInfo.hostname || "localhost"
    readonly property string prompt: `${SysInfo.user}@${host}`

    // The fetch block's rows as [label, value], leaving out any with nothing to say
    readonly property var facts: [
        [Tr.tr("os"), SysInfo.osPrettyName || SysInfo.osName],
        [Tr.tr("kernel"), SysInfo.kernel],
        [Tr.tr("wm"), SysInfo.wm],
        [Tr.tr("uptime"), SysInfo.uptimeShort],
        [Tr.tr("weather"), Weather.cc ? `${Weather.temp}, ${Weather.description}` : ""]
    ].filter(f => !!f[1])
    readonly property int labelWidth: Math.max(...facts.map(f => f[0].length))

    StatusChips {
        x: root.width - width - root.margin
        y: root.margin
        uiScale: root.uiScale * 0.9
        layoutDirection: Qt.RightToLeft
    }

    SessionBar {
        anchors.horizontalCenter: parent.horizontalCenter
        y: term.y + term.height + Tokens.spacing.extraLarge * 1.5 * root.uiScale
        uiScale: root.uiScale * 0.9
    }

    StyledRect {
        id: term

        anchors.centerIn: parent
        width: Math.min(root.width - root.margin * 2, 860 * root.uiScale)
        implicitHeight: titleBar.height + body.implicitHeight + root.pad * 2
        radius: Tokens.rounding.large * root.uiScale
        color: Colours.tPalette.m3surface
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 30
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }

        // Title bar: three window buttons, the window's title, and the time
        StyledRect {
            id: titleBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 44 * root.uiScale
            topLeftRadius: term.radius
            topRightRadius: term.radius
            color: Colours.tPalette.m3surfaceContainer

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.large * root.uiScale
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small * root.uiScale

                Repeater {
                    model: [Colours.palette.m3error, Colours.palette.m3tertiary, Colours.palette.m3primary]

                    Rectangle {
                        required property color modelData

                        width: 13 * root.uiScale
                        height: width
                        radius: width / 2
                        color: Qt.alpha(modelData, 0.85)
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: `${root.prompt}: ~`
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.mono.builders.small.scale(root.uiScale).weight(Font.DemiBold).build()
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.large * root.uiScale
                anchors.verticalCenter: parent.verticalCenter
                text: Time.format(Units.twelveHourClock ? "h:mm A" : "hh:mm")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.mono.builders.small.scale(root.uiScale).weight(Font.DemiBold).build()
            }
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.margins: root.pad
            spacing: Tokens.spacing.small * root.uiScale

            // The issue line, the way a console introduces itself
            Line {
                // TRANSLATORS: %1 = OS name, %2 = kernel version, %3 = host name - a text console's login banner
                text: Tr.tr("%1 %2 (%3) (tty1)").arg(SysInfo.osPrettyName || SysInfo.osName).arg(SysInfo.kernel).arg(root.host)
                color: Colours.palette.m3onSurfaceVariant
            }

            Item {
                implicitHeight: Tokens.spacing.medium * root.uiScale
            }

            Repeater {
                model: root.facts

                RowLayout {
                    id: fact

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 0

                    Line {
                        text: fact.modelData[0].padEnd(root.labelWidth + 2, " ")
                        color: Colours.palette.m3primary
                        font: root.monoBold
                    }

                    Line {
                        Layout.fillWidth: true
                        text: fact.modelData[1]
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                implicitHeight: Tokens.spacing.medium * root.uiScale
            }

            Prompt {
                command: "date"
            }

            Line {
                text: Time.format("ddd d MMM yyyy, hh:mm")
            }

            Item {
                implicitHeight: Tokens.spacing.medium * root.uiScale
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.large * root.uiScale

                Line {
                    id: passwordLabel

                    Layout.alignment: Qt.AlignVCenter
                    // TRANSLATORS: the prompt before the password field, as a text console words it
                    text: Tr.tr("Password:")
                    font: root.monoBold
                }

                PasswordField {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    focus: true
                    lock: root.lock
                    uiScale: root.uiScale
                    // Off the window rather than this field's own width, which the field's
                    // implicit width feeds into
                    fieldWidth: term.width - root.pad * 2 - passwordLabel.implicitWidth - Tokens.spacing.large * root.uiScale
                }
            }

            // Wrong-password and state lines, hung under the prompt without reserving a line
            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                Layout.maximumHeight: 0
                active: !!root.lock
                visible: active

                sourceComponent: StateMessage {
                    pam: root.lock.pam
                }
            }
        }
    }

    component Line: StyledText {
        color: Colours.palette.m3onSurface
        font: root.mono
    }

    // "user@host ~ $ command", with the user and the $ in the accent
    component Prompt: RowLayout {
        id: promptRow

        property string command

        spacing: 0

        Line {
            text: root.prompt
            color: Colours.palette.m3tertiary
            font: root.monoBold
        }

        Line {
            text: " ~ "
            color: Colours.palette.m3onSurfaceVariant
        }

        Line {
            text: "$ "
            color: Colours.palette.m3primary
            font: root.monoBold
        }

        Line {
            text: promptRow.command
        }
    }
}
