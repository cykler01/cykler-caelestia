pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.background

// --- Fetch: a neofetch-style summary of the machine, in the same voice as the lock screen's, as a card or as a
// terminal window ---
WidgetCard {
    id: fetch

    // Installed package count, counted once per session in services/WidgetData.qml so a card that comes
    // back after the desktop was hidden doesn't wait for pacman again. -1 until it has an answer; pacman is
    // the only package manager this shell supports, so there is nothing to probe for
    readonly property int packageCount: WidgetData.packageCount

    readonly property bool compact: fetch.variant === "compact"
    readonly property bool terminal: fetch.variant === "terminal"
    // The window's own title bar takes the card's edge, so the terminal draws its own insets
    readonly property string prompt: `${SysInfo.user}@${SysInfo.hostname}`

    // Only the lines with something to say; the labels are padded to one width below so the
    // values still line up whatever is missing
    readonly property var rows: {
        const list = [
            {
                label: Tr.tr("OS"),
                value: SysInfo.osPrettyName || SysInfo.osName
            },
            {
                label: Tr.tr("Kernel"),
                value: SysInfo.kernel
            },
            {
                label: Tr.tr("Uptime"),
                value: SysInfo.uptimeShort
            },
            {
                label: Tr.tr("Packages"),
                value: fetch.packageCount > 0 ? Tr.tr("%1 (pacman)").arg(fetch.packageCount) : ""
            },
            {
                label: Tr.tr("Shell"),
                value: SysInfo.shell
            },
            {
                label: Tr.tr("WM"),
                value: SysInfo.wm
            },
            {
                label: Tr.tr("CPU"),
                value: Cpu.name
            },
            {
                label: Tr.tr("GPU"),
                value: Gpu.name
            },
            {
                label: Tr.tr("Memory"),
                value: Units.formatKibUsage(Memory.used, Memory.total)
            }
        ];
        // Compact keeps the four lines that say what the machine is; the rest is detail
        const essentials = [Tr.tr("OS"), Tr.tr("Kernel"), Tr.tr("Uptime"), Tr.tr("Memory")];
        return list.filter(r => r.value && (!fetch.compact || essentials.includes(r.label)));
    }
    // Monospace, so padding the labels to the longest of them lines the values up
    readonly property int labelChars: fetch.rows.reduce((n, r) => Math.max(n, r.label.length), 0)

    title: ""
    icon: ""
    padding: fetch.terminal ? 0 : Tokens.padding.largeIncreased

    Component.onCompleted: WidgetData.ensurePackages()

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Gpu
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !fetch.terminal
        spacing: Tokens.spacing.small

        // The command whose output the card reads like
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: ">"
                color: Colours.palette.m3primary
                font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                text: "caelestiafetch"
                elide: Text.ElideRight
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.mono.small
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: `${SysInfo.user}@${SysInfo.hostname}`
            elide: Text.ElideRight
            color: Colours.palette.m3primary
            font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.bottomMargin: Tokens.spacing.extraSmall
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        Repeater {
            model: fetch.rows

            RowLayout {
                id: infoRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: infoRow.modelData.label + " ".repeat(fetch.labelChars - infoRow.modelData.label.length)
                    color: Colours.palette.m3primary
                    font: Tokens.font.mono.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: infoRow.modelData.value
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.mono.small
                }
            }
        }

        // The terminal palette, as a single strip
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: !fetch.compact
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: 8

                StyledRect {
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: Tokens.rounding.full
                    color: Colours.palette[`term${index}`]
                }
            }
        }
    }

    // Terminal: the same lines as they would come out of a shell, in a window with a title bar, the logo
    // beside them and a prompt waiting underneath
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: fetch.terminal
        spacing: 0

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 34
            topLeftRadius: fetch.radius
            topRightRadius: fetch.radius
            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.55)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.large
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                Repeater {
                    model: [Colours.palette.m3error, Colours.palette.m3tertiary, Colours.palette.m3primary]

                    StyledRect {
                        required property color modelData

                        implicitWidth: 11
                        implicitHeight: 11
                        radius: Tokens.rounding.full
                        color: modelData
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 140)
                elide: Text.ElideRight
                text: `${fetch.prompt}: ~`
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.mono.small
            }

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            PromptLine {
                command: "caelestiafetch"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: Tokens.padding.large

                Loader {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.spacing.small
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 84
                    asynchronous: true

                    sourceComponent: SysInfo.isDefaultLogo ? termLogo : termDistroIcon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    Repeater {
                        model: fetch.rows

                        RowLayout {
                            id: termRow

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: termRow.modelData.label + " ".repeat(fetch.labelChars - termRow.modelData.label.length + 1)
                                color: Colours.palette.m3primary
                                font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: termRow.modelData.value
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.mono.small
                            }
                        }
                    }

                    // The terminal's sixteen colours as blocks, the way fetch tools sign off
                    Grid {
                        Layout.topMargin: Tokens.spacing.medium
                        columns: 8
                        spacing: 0

                        Repeater {
                            model: 16

                            Rectangle {
                                required property int index

                                width: 18
                                height: 10
                                color: Colours.palette[`term${index}`]
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            PromptLine {
                waiting: true
            }
        }
    }

    // A shell prompt: who and where in the scheme's colours, then the command, or a cursor waiting for one
    component PromptLine: RowLayout {
        id: promptLine

        property string command
        property bool waiting

        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: fetch.prompt
            color: Colours.palette.m3primary
            font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
        }

        StyledText {
            text: " ~ "
            color: Colours.palette.m3tertiary
            font: Tokens.font.mono.small
        }

        StyledText {
            text: "$ "
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.mono.small
        }

        StyledText {
            Layout.fillWidth: !promptLine.waiting
            visible: !promptLine.waiting
            elide: Text.ElideRight
            text: promptLine.command
            color: Colours.palette.m3onSurface
            font: Tokens.font.mono.small
        }

        // Blinks only while animations are on; otherwise it simply stays lit
        StyledRect {
            id: caret

            visible: promptLine.waiting
            implicitWidth: 8
            implicitHeight: 15
            color: Colours.palette.m3onSurface

            Timer {
                interval: 600
                repeat: true
                running: caret.visible && fetch.terminal && PowerSaving.animations
                onTriggered: caret.opacity = caret.opacity > 0 ? 0 : 1
                onRunningChanged: {
                    if (!running)
                        caret.opacity = 1;
                }
            }
        }

        Item {
            visible: promptLine.waiting
            Layout.fillWidth: true
        }
    }

    Component {
        id: termLogo

        Logo {}
    }

    Component {
        id: termDistroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: 84
            colour: Colours.palette.m3primary
        }
    }
}
