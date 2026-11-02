pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.utils
import qs.modules.background

// --- Fetch: a neofetch-style summary of the machine, in the same voice as the lock screen's ---
WidgetCard {
    id: fetch

    // Installed package count. Counted here rather than on the desktop so the card is whole on its
    // own and the previews show a real number too; pacman is the only package manager this shell
    // supports, so there is nothing to probe for
    property int packageCount

    readonly property bool compact: fetch.variant === "compact"

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

    Process {
        running: true
        command: ["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"]

        stdout: StdioCollector {
            onStreamFinished: fetch.packageCount = parseInt(text()) || 0
        }
    }
}
