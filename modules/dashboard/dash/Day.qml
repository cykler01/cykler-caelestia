pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.misc
import qs.components.widgets
import qs.services

// The home page's day progress card: where you are in the day, over a timeline of today's
// events (components/widgets/DayProgress.qml)
Item {
    id: root

    anchors.fill: parent
    anchors.margins: Tokens.padding.large
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2

    Ref {
        service: CalendarEvents
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            visible: !CalendarEvents.ready
            wrapMode: Text.Wrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
            text: {
                if (!CalendarEvents.available)
                    return Tr.tr("Install evolution-data-server to see your GNOME Calendar events");
                if (!CalendarEvents.enabled)
                    return Tr.tr("Calendar events are turned off in the dashboard settings");
                return Tr.tr("Reading your calendars…");
            }
        }

        DayProgress {
            Layout.fillWidth: true
            visible: CalendarEvents.ready
        }
    }
}
