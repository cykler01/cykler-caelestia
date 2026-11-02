pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Calendar: a month grid, or a strip of the week we are in ---
WidgetCard {
    id: cal

    readonly property date now: Time.date
    readonly property bool weekView: cal.variant === "week"

    // Monday first, so a week always starts on the day most calendars here do
    readonly property var cells: {
        const first = new Date(now.getFullYear(), now.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        return Array.from({
            length: 42
        }, (_, i) => {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            return {
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                today: d.toDateString() === now.toDateString()
            };
        });
    }

    readonly property var week: {
        const day = new Date(cal.now.getFullYear(), cal.now.getMonth(), cal.now.getDate());
        const offset = (day.getDay() + 6) % 7;
        return Array.from({
            length: 7
        }, (_, i) => {
            const d = new Date(day.getFullYear(), day.getMonth(), day.getDate() - offset + i);
            return {
                day: d.getDate(),
                weekday: Qt.locale().dayName(d.getDay(), Locale.NarrowFormat),
                today: d.toDateString() === cal.now.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            };
        });
    }

    title: cal.weekView ? Tr.tr("This week") : Time.format("MMMM yyyy")
    icon: cal.weekView ? "calendar_view_week" : "calendar_month"

    // Month: the whole grid
    GridLayout {
        Layout.fillWidth: true
        visible: !cal.weekView
        columns: 7
        rowSpacing: 2
        columnSpacing: 0

        Repeater {
            model: [1, 2, 3, 4, 5, 6, 0]

            StyledText {
                required property int modelData

                // Same preferred width as the day cells, so all seven columns come out
                // equal: a GridLayout sizes each column to its widest cell, which lines the
                // narrow weekday letters up differently from the two-digit dates
                Layout.preferredWidth: 1
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
                color: Colours.palette.m3primary
                font: Tokens.font.label.small
            }
        }

        Repeater {
            model: cal.cells

            Item {
                id: cell

                required property var modelData

                Layout.preferredWidth: 1
                Layout.fillWidth: true
                implicitHeight: 30

                StyledRect {
                    anchors.centerIn: parent
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: cell.modelData.today ? Colours.palette.m3primary : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: cell.modelData.day
                    font: Tokens.font.label.medium
                    color: cell.modelData.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    opacity: cell.modelData.inMonth ? 1 : 0.3
                }
            }
        }
    }

    // Week: seven days, today picked out
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: cal.weekView
        spacing: 0
        uniformCellSizes: true

        Repeater {
            model: cal.week

            ColumnLayout {
                id: weekDay

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: weekDay.modelData.weekday.toUpperCase()
                    color: weekDay.modelData.today ? Colours.palette.m3primary : Colours.palette.m3outline
                    font: Tokens.font.label.small
                }

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: Tokens.rounding.full
                    color: weekDay.modelData.today ? Colours.palette.m3primary : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: weekDay.modelData.day
                        color: weekDay.modelData.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font: Tokens.font.title.medium
                        opacity: weekDay.modelData.weekend && !weekDay.modelData.today ? 0.6 : 1
                    }
                }
            }
        }
    }
}
