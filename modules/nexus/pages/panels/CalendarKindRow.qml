import QtQuick
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Which kind one of GNOME Calendar's calendars counts as (services/CalendarEvents.qml): sorted
// event by event, or every event in it regular, special or rare
SelectRow {
    id: root

    required property string calendarUid
    required property string calendarName

    readonly property string kind: CalendarEvents.kindOverrides[root.calendarUid] ?? "auto"

    readonly property list<MenuItem> kindItems: [
        MenuItem {
            text: Tr.trCtx("Automatic", "event kind")
            icon: "auto_awesome"
            value: "auto"
        },
        MenuItem {
            text: Tr.trCtx("Regular", "event kind")
            icon: "event_repeat"
            value: "regular"
        },
        MenuItem {
            text: Tr.trCtx("Special", "event kind")
            icon: "star"
            value: "special"
        },
        MenuItem {
            text: Tr.trCtx("Rare", "event kind")
            icon: "cake"
            value: "rare"
        }
    ]

    label: root.calendarName
    subtext: root.kind === "auto" ? Tr.tr("By how often each event repeats") : ""
    menuItems: root.kindItems
    active: root.kindItems.find(item => item.value === root.kind) ?? null
    onSelected: item => CalendarEvents.setCalendarKind(root.calendarUid, item.value)
}
