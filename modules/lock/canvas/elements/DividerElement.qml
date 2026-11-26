import QtQuick
import qs.modules.lock.canvas

// A thin rounded line filling its box, lying down or standing up as the box is wider or taller
Item {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    Rectangle {
        anchors.centerIn: parent
        width: root.width >= root.height ? root.width : Math.max(1, 2 * root.s)
        height: root.width >= root.height ? Math.max(1, 2 * root.s) : root.height
        radius: Math.min(width, height) / 2
        color: Qt.alpha(ElementCatalog.colour(root.opts.colour ?? "variant"), 0.5)
    }
}
