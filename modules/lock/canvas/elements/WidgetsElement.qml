import QtQuick
import qs.modules.lock
import qs.modules.lock.canvas

// A stack of the lock screen widgets (weather, media, notifications, ...), the ones picked in its
// options, in that order. It fills the box it's given, sharing the room out by each widget's
// weight, and drops the last widgets that won't fit whole
Item {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null

    WidgetColumn {
        anchors.fill: parent
        side: root.opts.column ?? "left"
        widgetIds: ElementCatalog.widgetsFor(root.opts)
        rootHeight: height
        fitHeight: height
        minFlexHeight: 125 * root.s
        lock: root.lock
    }
}
