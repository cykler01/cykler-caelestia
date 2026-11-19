pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.misc
import qs.components.widgets
import qs.services
import qs.modules.background

// --- Day progress: where you are in the day, over a timeline of today's events
// (components/widgets/DayProgress.qml), in full or as a slim strip ---
WidgetCard {
    id: card

    readonly property bool compact: card.variant === "compact"

    title: card.compact ? "" : Tr.tr("Your day")
    icon: "timelapse"

    onClicked: {
        if (!card.preview)
            CalendarEvents.openDate(Time.date);
    }

    Ref {
        service: CalendarEvents
    }

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
        compact: card.compact
        interactive: !card.preview
    }

    Item {
        Layout.fillHeight: true
    }
}
