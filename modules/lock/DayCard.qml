pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.misc
import qs.components.widgets
import qs.services

// Where you are in the day, over a timeline of today's events (components/widgets/DayProgress.qml).
// Sized to its content like the battery card, and inert, the screen being locked
StyledRect {
    id: root

    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Ref {
        service: CalendarEvents
    }

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            visible: !CalendarEvents.ready
            wrapMode: Text.Wrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
            text: !CalendarEvents.available ? Tr.tr("GNOME Calendar's events are not available") : !CalendarEvents.enabled ? Tr.tr("Calendar events are turned off") : Tr.tr("Reading your calendars…")
        }

        DayProgress {
            Layout.fillWidth: true
            visible: CalendarEvents.ready
            interactive: false
        }
    }
}
