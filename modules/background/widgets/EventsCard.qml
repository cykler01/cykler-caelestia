pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.misc
import qs.components.widgets
import qs.services
import qs.modules.background

// --- Events: GNOME Calendar's events (services/CalendarEvents.qml) - what is coming up a day at a
// time, just today's, or the next one large with a countdown ---
WidgetCard {
    id: card

    readonly property bool todayView: card.variant === "today"
    readonly property bool nextView: card.variant === "next"
    readonly property bool listView: !card.todayView && !card.nextView

    // Flattened for the list: a row for each day's heading, then its events. A list of plain rows
    // scrolls and fades the way the to-do card's does, where nested repeaters would not
    readonly property var rows: {
        if (!CalendarEvents.ready)
            return [];
        if (card.todayView)
            return CalendarEvents.today.map(e => ({
                        heading: false,
                        event: e,
                        day: Time.date
                    }));

        const out = [];
        for (const g of CalendarEvents.grouped(30)) {
            out.push({
                heading: true,
                day: g.day
            });
            for (const e of g.events)
                out.push({
                    heading: false,
                    event: e,
                    day: g.day
                });
        }
        return out;
    }

    readonly property var next: CalendarEvents.next

    // Why there is nothing to show, or empty when there is something
    readonly property string note: {
        if (!CalendarEvents.available)
            return Tr.tr("Install evolution-data-server to see your GNOME Calendar events");
        if (!CalendarEvents.enabled)
            return Tr.tr("Calendar events are turned off in the dashboard settings");
        if (!CalendarEvents.loaded)
            return Tr.tr("Reading your calendars…");
        if (card.nextView && !card.next)
            return Tr.tr("Nothing in the next %1 days").arg(CalendarEvents.lookahead);
        if (card.todayView && card.rows.length === 0)
            return Tr.tr("Nothing on today");
        if (card.listView && card.rows.length === 0)
            return Tr.tr("Nothing in the next %1 days").arg(CalendarEvents.lookahead);
        return "";
    }

    title: card.todayView ? Tr.tr("Today") : card.nextView ? Tr.tr("Next up") : Tr.tr("Coming up")
    icon: card.nextView ? "alarm" : card.todayView ? "today" : "event"

    // A click on the card's bare space opens the calendar, on the next event for the large view
    onClicked: {
        if (card.preview)
            return;
        if (card.nextView && card.next)
            CalendarEvents.openEvent(card.next);
        else
            CalendarEvents.openApp();
    }

    Ref {
        service: CalendarEvents
    }

    StyledText {
        Layout.fillWidth: true
        visible: card.note !== ""
        wrapMode: Text.Wrap
        text: card.note
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    // For a quiet today, what comes after it
    EventRow {
        Layout.fillWidth: true
        visible: card.todayView && card.rows.length === 0 && card.next !== null
        event: card.next ?? ({
                start: new Date(),
                end: new Date(),
                allDay: true,
                summary: ""
            })
        day: card.next?.start ?? new Date()
        relative: true
        interactive: !card.preview
    }

    // Coming up and today: the rows, scrolling once there are more than the card is tall for
    Item {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        implicitHeight: Math.min(rowsView.contentHeight, 26 * 4)
        visible: !card.nextView && card.rows.length > 0

        VerticalFadeListView {
            id: rowsView

            anchors.fill: parent
            clip: true
            spacing: 0
            model: card.rows
            interactive: !card.preview

            delegate: Loader {
                id: row

                required property var modelData
                required property int index

                width: rowsView.width
                sourceComponent: row.modelData.heading ? headingRow : eventRow

                Component {
                    id: headingRow

                    StyledText {
                        topPadding: row.index > 0 ? Tokens.spacing.small : 0
                        leftPadding: Tokens.padding.small
                        text: CalendarEvents.dayLabel(row.modelData.day)
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                    }
                }

                Component {
                    id: eventRow

                    EventRow {
                        event: row.modelData.event
                        day: row.modelData.day
                        relative: true
                        interactive: !card.preview
                    }
                }
            }
        }
    }

    // Next: the one event, large, with how long until it starts
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: card.nextView && card.next !== null
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                implicitWidth: 6
                radius: 3
                color: CalendarEvents.colourOf(card.next)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: CalendarEvents.titleOf(card.next)
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.next ? `${CalendarEvents.dayLabel(card.next.start < Time.date ? Time.date : card.next.start)} · ${CalendarEvents.timeLabel(card.next, card.next.start < Time.date ? Time.date : card.next.start)}` : ""
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.next?.location ?? ""
                    elide: Text.ElideRight
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // The countdown, as a pill in the event's colour
        StyledRect {
            implicitWidth: countdown.implicitWidth + Tokens.padding.large * 2
            implicitHeight: countdown.implicitHeight + Tokens.padding.small
            radius: Tokens.rounding.full
            color: Qt.alpha(CalendarEvents.colourOf(card.next), 0.2)

            StyledText {
                id: countdown

                anchors.centerIn: parent
                text: card.next ? CalendarEvents.relativeLabel(card.next) : ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }
        }
    }
}
