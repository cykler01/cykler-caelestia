import QtQuick
import qs.components

// NOTE(fork): GridView's StyledListView. A plain GridView has no WheelScroller, so the wheel and
// the trackpad write straight into contentY and the grid lurches and parks itself past its own
// ends - see WheelScroller for why. Everything that scrolls should be one of these.
GridView {
    id: root

    property bool doneFakeFlick

    // Whether the wheel/trackpad scroller is driving the content right now,
    // the equivalent of `moving` for a drag or a flick
    readonly property alias wheelScrolling: scroller.active

    maximumFlickVelocity: 3000

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

    WheelScroller {
        id: scroller

        flickable: root
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
