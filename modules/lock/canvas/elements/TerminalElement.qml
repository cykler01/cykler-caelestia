pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// After a getty login on a text console: the banner a console greets you with, a short fetch of
// the system, and the date as if typed at a prompt, all in monospace. Pairs with a panel that has
// a window title bar, and a password field with a "Password:" prompt, for the whole console look
ColumnLayout {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    readonly property font mono: Tokens.font.mono.builders.medium.scale(s * 1.15).build()
    readonly property font monoBold: Tokens.font.mono.builders.medium.scale(s * 1.15).weight(Font.Bold).build()
    readonly property string host: SysInfo.hostname || "localhost"
    readonly property var facts: [
        [Tr.tr("os"), SysInfo.osPrettyName || SysInfo.osName],
        [Tr.tr("kernel"), SysInfo.kernel],
        [Tr.tr("wm"), SysInfo.wm],
        [Tr.tr("uptime"), SysInfo.uptimeShort],
        [Tr.tr("weather"), Weather.cc ? `${Weather.temp}, ${Weather.description}` : ""]
    ].filter(f => !!f[1])
    readonly property int labelWidth: Math.max(...facts.map(f => f[0].length))

    spacing: Tokens.spacing.small * s

    Line {
        visible: root.opts.banner ?? true
        Layout.bottomMargin: Tokens.spacing.medium * root.s
        // TRANSLATORS: %1 = OS name, %2 = kernel version, %3 = host name - a text console's login banner
        text: Tr.tr("%1 %2 (%3) (tty1)").arg(SysInfo.osPrettyName || SysInfo.osName).arg(SysInfo.kernel).arg(root.host)
        color: Colours.palette.m3onSurfaceVariant
    }

    Repeater {
        model: (root.opts.facts ?? true) ? root.facts : []

        RowLayout {
            id: fact

            required property var modelData

            spacing: 0

            Line {
                text: fact.modelData[0].padEnd(root.labelWidth + 2, " ")
                color: Colours.palette.m3primary
                font: root.monoBold
            }

            Line {
                text: fact.modelData[1]
            }
        }
    }

    RowLayout {
        visible: root.opts.date ?? true
        Layout.topMargin: Tokens.spacing.medium * root.s
        spacing: 0

        Line {
            text: `${SysInfo.user}@${root.host}`
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
            text: "date"
        }
    }

    Line {
        visible: root.opts.date ?? true
        text: Time.format("ddd d MMM yyyy, hh:mm")
    }

    component Line: StyledText {
        color: Colours.palette.m3onSurface
        font: root.mono
    }
}
