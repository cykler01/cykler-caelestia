import QtQuick
import qs.modules.lock.center

// The greeting, worded as set under Nexus > Lock screen > Greeting. It has no size of its own to
// set, so it's scaled as a whole
Item {
    id: root

    property real s: 1

    property var opts: ({})

    property var lock: null

    implicitWidth: greeting.implicitWidth * root.s
    implicitHeight: greeting.implicitHeight * root.s

    Greeting {
        id: greeting

        scale: root.s
        transformOrigin: Item.TopLeft
    }
}
