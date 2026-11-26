import QtQuick
import qs.modules.lock

// A column of the lock screen widgets (weather, media, notifications, ...), the ones assigned to
// the chosen column in Nexus > Lock screen > Widgets, or all of them. It fills the box it's given,
// sharing the room out by each widget's weight, and drops the last widgets that won't fit whole
Item {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null

    WidgetColumn {
        anchors.fill: parent
        side: root.opts.column ?? "left"
        rootHeight: height
        fitHeight: height
        minFlexHeight: 125 * root.s
        lock: root.lock
    }
}
