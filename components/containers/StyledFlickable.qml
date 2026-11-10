import QtQuick
import qs.components

Flickable {
    id: root

    property bool doneFakeFlick

    // Whether the wheel/trackpad scroller is driving the content right now,
    // the equivalent of `moving` for a drag or a flick
    readonly property alias wheelScrolling: scroller.active

    maximumFlickVelocity: 3000

    WheelScroller {
        id: scroller

        flickable: root
    }

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root.cancelFlick());
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
