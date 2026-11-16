pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background
import qs.modules.launcher.services

// --- Calendar: a month grid, a strip of the week we are in, today's date as a tear-off page, or
// what is coming up over the next week ---
WidgetCard {
    id: cal

    readonly property date now: Time.date
    readonly property bool weekView: cal.variant === "week"
    readonly property bool todayView: cal.variant === "today"
    readonly property bool agendaView: cal.variant === "agenda"
    readonly property bool monthView: !cal.weekView && !cal.todayView && !cal.agendaView

    // How many entries the agenda has room for in its footprint
    readonly property int agendaRows: 4

    // Tasks with a deadline and alarms due over the coming week, soonest first, each tagged with the
    // day it falls on so the list can put the day beside the first entry of each. Overdue tasks
    // lead, under a day of their own, since they are the ones most worth seeing. Read through the
    // to-do revision and the alarm list so edits elsewhere show up straight away
    readonly property var agenda: {
        void Todo.revision;
        const alarms = Alarms.alarms;
        const now = cal.now;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const horizon = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 7).getTime();
        const entries = [];

        for (const t of Todo.tasks) {
            if (t.done || !t.deadline)
                continue;
            const d = new Date(t.deadline);
            if (isNaN(d.getTime()) || d.getTime() >= horizon)
                continue;
            entries.push({
                kind: "task",
                id: t.id,
                text: t.text,
                at: d.getTime(),
                overdue: d.getTime() < today.getTime(),
                // A deadline at midnight is a whole day rather than a time in it
                timed: d.getHours() !== 0 || d.getMinutes() !== 0
            });
        }

        for (const a of alarms) {
            if (!a.enabled || a.nextAt <= 0 || a.nextAt >= horizon)
                continue;
            entries.push({
                kind: "alarm",
                id: a.id,
                text: a.label || Tr.tr("Alarm"),
                at: a.nextAt,
                overdue: false,
                timed: true
            });
        }

        entries.sort((a, b) => a.at - b.at);

        let lastDay = "";
        return entries.slice(0, cal.agendaRows).map(e => {
            const day = e.overdue ? "overdue" : new Date(e.at).toDateString();
            const first = day !== lastDay;
            lastDay = day;
            return Object.assign({}, e, {
                day,
                first
            });
        });
    }

    function dayLabel(entry: var): string {
        if (entry.overdue)
            return Tr.tr("Overdue");
        const d = new Date(entry.at);
        const today = new Date(cal.now.getFullYear(), cal.now.getMonth(), cal.now.getDate());
        const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        if (diff === 0)
            return Tr.tr("Today");
        if (diff === 1)
            return Tr.tr("Tomorrow");
        return Qt.formatDate(d, "ddd d");
    }

    function entryTime(entry: var): string {
        if (entry.overdue)
            return Qt.formatDate(new Date(entry.at), "d MMM");
        if (!entry.timed)
            return "";
        return Qt.formatTime(new Date(entry.at), Units.twelveHourClock ? "h:mm AP" : "HH:mm");
    }

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

    title: cal.todayView ? "" : cal.agendaView ? Tr.tr("Coming up") : cal.weekView ? Tr.tr("This week") : Time.format("MMMM yyyy")
    icon: cal.agendaView ? "event_upcoming" : cal.weekView ? "calendar_view_week" : "calendar_month"

    // Month: the whole grid
    GridLayout {
        Layout.fillWidth: true
        visible: cal.monthView
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

    // Today: a page off a desk calendar - the month on a coloured binding strip, the date big under it
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: cal.todayView
        visible: active

        sourceComponent: StyledRect {
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            clip: true

            StyledRect {
                id: strip

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: monthLabel.implicitHeight + Tokens.padding.small * 2
                topLeftRadius: Tokens.rounding.large
                topRightRadius: Tokens.rounding.large
                color: Colours.palette.m3primary

                StyledText {
                    id: monthLabel

                    anchors.centerIn: parent
                    text: Qt.formatDate(cal.now, "MMMM").toUpperCase()
                    color: Colours.palette.m3onPrimary
                    font: Tokens.font.label.builders.medium.letterSpacing(1.5).weight(Font.Bold).build()
                }

                // The two rings the page hangs from
                Repeater {
                    model: 2

                    StyledRect {
                        required property int index

                        x: index === 0 ? Tokens.padding.small : strip.width - width - Tokens.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: Tokens.padding.extraSmall * 1.5
                        implicitHeight: Tokens.padding.extraSmall * 1.5
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHigh
                    }
                }
            }

            StyledText {
                id: dayNumber

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: strip.bottom
                anchors.bottom: weekdayLabel.top
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPointSize: Tokens.font.label.small.pointSize
                text: cal.now.getDate()
                color: Colours.palette.m3onSurface
                font: Tokens.font.clock.size(300).weight(Font.Bold).build()
            }

            StyledText {
                id: weekdayLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.padding.small
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: `${Qt.formatDate(cal.now, "dddd")} \u00b7 ${cal.now.getFullYear()}`
                color: Colours.palette.m3primary
                font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
            }
        }
    }

    // Agenda: the day down the left beside its first entry, so a run of entries on one day reads
    // as a group without spending a row on a heading
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: cal.agendaView
        visible: active

        sourceComponent: Item {
            id: agendaList

            // The day column is as wide as the longest thing it can say, whatever the language
            readonly property real dayWidth: Math.max(...[Tr.tr("Overdue"), Tr.tr("Today"), Tr.tr("Tomorrow"), Qt.formatDate(new Date(2026, 0, 28), "ddd d")].map(t => {
                    dayMetrics.text = t;
                    return dayMetrics.advanceWidth;
                })) + Tokens.spacing.extraSmall

            clip: true

            TextMetrics {
                id: dayMetrics

                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: cal.agenda.length > 0
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: cal.agenda

                    RowLayout {
                        id: entry

                        required property var modelData
                        required property int index

                        readonly property bool alarm: entry.modelData.kind === "alarm"
                        readonly property color accent: entry.modelData.overdue ? Colours.palette.m3error : entry.alarm ? Colours.palette.m3tertiary : Colours.palette.m3primary

                        Layout.fillWidth: true
                        Layout.topMargin: entry.modelData.first && entry.index > 0 ? Tokens.spacing.small : 0
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.preferredWidth: agendaList.dayWidth
                            elide: Text.ElideRight
                            opacity: entry.modelData.first ? 1 : 0
                            text: cal.dayLabel(entry.modelData)
                            color: entry.modelData.overdue ? Colours.palette.m3error : entry.modelData.day === cal.now.toDateString() ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: entryRow.implicitHeight + Tokens.padding.extraSmall * 2
                            radius: Tokens.rounding.small
                            color: Qt.alpha(entry.accent, 0.12)

                            RowLayout {
                                id: entryRow

                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.small
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small

                                Item {
                                    implicitWidth: entryIcon.implicitWidth
                                    implicitHeight: entryIcon.implicitHeight

                                    MaterialIcon {
                                        id: entryIcon

                                        text: entry.alarm ? "alarm" : "radio_button_unchecked"
                                        color: entry.accent
                                        fontStyle: Tokens.font.icon.small
                                    }

                                    // A task can be ticked off from here, as on the to-do card
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !entry.alarm
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: Todo.toggleDone(entry.modelData.id)
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: entry.modelData.text
                                    color: Colours.palette.m3onSurface
                                    font: Tokens.font.body.small
                                }

                                StyledText {
                                    visible: text !== ""
                                    text: cal.entryTime(entry.modelData)
                                    color: entry.accent
                                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                }
                            }
                        }
                    }
                }
            }

            // Nothing in the coming week: say so kindly rather than leave the card blank
            ColumnLayout {
                anchors.centerIn: parent
                visible: cal.agenda.length === 0
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "event_available"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.2).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("Nothing coming up")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("No deadlines or alarms this week")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }
            }
        }
    }
}
