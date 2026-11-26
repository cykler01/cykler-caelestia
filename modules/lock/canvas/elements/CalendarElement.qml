pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// This month as a grid: the month's name, the weekday initials, and the days, with today on an
// accent disc and the days of the neighbouring months left out
ColumnLayout {
    id: root

    property real s: 1

    property var opts: ({})

    property var lock: null

    readonly property date today: Time.date
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    // Monday first
    readonly property int lead: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property real cell: 40 * root.s

    spacing: Tokens.spacing.medium * root.s

    StyledText {
        text: Time.format("MMMM yyyy")
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.DemiBold).build()
    }

    Grid {
        columns: 7

        Repeater {
            // Monday 6 Jan 2025 onwards, so the initials come out in the user's own language
            model: 7

            StyledText {
                required property int index

                width: root.cell
                horizontalAlignment: Text.AlignHCenter
                text: Tr.formatDateTime(new Date(2025, 0, 6 + index), "ddd").charAt(0)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.large.scale(root.s).weight(Font.DemiBold).build()
            }
        }

        Repeater {
            model: root.lead + root.days

            Item {
                id: day

                required property int index

                readonly property int number: index - root.lead + 1
                readonly property bool isToday: number === root.today.getDate()

                width: root.cell
                height: root.cell

                StyledRect {
                    anchors.centerIn: parent
                    width: root.cell * 0.85
                    height: width
                    radius: width / 2
                    visible: day.isToday
                    color: Colours.palette.m3primary
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: day.number > 0
                    text: day.number
                    color: day.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.medium.scale(root.s).weight(day.isToday ? Font.Bold : Font.Normal).build()
                }
            }
        }
    }
}
