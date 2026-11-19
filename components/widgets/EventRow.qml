pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// One calendar event as a row: a bar in its calendar's colour, the title, and when it is. Shared
// by the event widgets on the desktop, the dashboard and the lock screen (services/CalendarEvents.qml
// has the events and the wording). Clicking opens the event in GNOME Calendar unless
// `interactive` is off, as it is on the lock screen.
Item {
    id: root

    required property var event
    // The day the row is listed under, which decides how a multi-day event reads ("Day 2 of 3")
    property date day: Time.date
    // "in 25 min" in place of the clock time, for lists of what is coming up
    property bool relative: false
    property bool interactive: true
    property font titleFont: Tokens.font.body.small
    property font timeFont: Tokens.font.label.small

    readonly property bool ongoing: CalendarEvents.isOngoing(event)
    readonly property bool over: CalendarEvents.isOver(event)

    implicitHeight: layout.implicitHeight + Tokens.padding.extraSmall * 2
    implicitWidth: layout.implicitWidth + Tokens.padding.small * 2

    opacity: over ? 0.5 : 1

    StateLayer {
        visible: root.interactive
        radius: Tokens.rounding.small
        onClicked: CalendarEvents.openEvent(root.event)
    }

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.fillHeight: true
            implicitWidth: 4
            radius: 2
            color: CalendarEvents.colourOf(root.event)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: CalendarEvents.titleOf(root.event)
            elide: Text.ElideRight
            color: Colours.palette.m3onSurface
            font: root.titleFont
        }

        StyledText {
            text: {
                if (root.ongoing)
                    return CalendarEvents.relativeLabel(root.event);
                if (root.relative && !root.over && !root.event.allDay && CalendarEvents.dayDiff(root.event.start) === 0)
                    return CalendarEvents.relativeLabel(root.event);
                return CalendarEvents.timeLabel(root.event, root.day);
            }
            color: root.ongoing ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font: root.timeFont
        }
    }
}
