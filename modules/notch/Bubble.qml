pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): a detached round island standing beside the notch pill, the way a live activity
// does on a phone's island: the pill keeps the clock and the music, and anything with an end to it
// (a countdown, a download) gets a circle of its own at either side.
//
// Its surface is not drawn here: the shared blob group paints it along with every other panel's
// (modules/drawers/ContentWindow.qml), so it carries the same colour, shadow and spring deform as
// the notch it stands beside, and is kept from melting into it by the group's exclude list. This
// is only the content, and the `prog` below is what the blob is sized by as well, so the circle
// and what is in it grow out of nothing together.
//
// Hovering opens it out into a pill carrying the detail a circle has no room for - what is
// downloading and how fast, when the countdown is due to ring. It opens away from the notch, so
// the circle itself stays where it was and the detail appears beside it. The two delays are the
// notch's own (hoverExpandDelay, collapseDelay): a pointer crossing the bubble on its way
// somewhere else does not set it going, and one that slips off it for an instant does not shut it.
Item {
    id: root

    property bool shown
    property real prog: shown ? 1 : 0

    // The circle's diameter, which is also the bubble's height and its closed width
    property real size
    // How much room the detail needs once it is open, from whatever is drawn inside
    property real detailWidth
    // The bubble on the notch's left opens leftwards, so its circle does not slide across
    property bool mirrored

    // How far its content stands off whatever it is beside. It is only the content: the surface
    // behind it reaches back under its neighbour so the two are drawn as one shape (see BubbleBg
    // in modules/drawers/ContentWindow.qml), which is why this can be set for how the ring and the
    // clock sit next to each other rather than for how the two shapes meet
    readonly property real gap: Tokens.spacing.small

    property bool expanded
    property real expandProg: expanded ? 1 : 0

    default property alias content: holder.data

    implicitWidth: root.size + (root.detailWidth + root.gap) * root.expandProg
    implicitHeight: root.size

    width: implicitWidth
    height: implicitHeight

    visible: prog > 0.001
    opacity: prog

    // Nothing to open while it is still on its way in or out
    onShownChanged: {
        if (!root.shown) {
            expandTimer.stop();
            collapseTimer.stop();
            root.expanded = false;
        }
    }

    Behavior on prog {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on expandProg {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hoverHandler.hovered && root.shown) {
                collapseTimer.stop();
                expandTimer.restart();
            } else {
                expandTimer.stop();
                collapseTimer.restart();
            }
        }
    }

    Timer {
        id: expandTimer

        interval: root.Config.notch.hoverExpandDelay
        onTriggered: root.expanded = true
    }

    Timer {
        id: collapseTimer

        interval: root.Config.notch.collapseDelay
        onTriggered: root.expanded = false
    }

    Item {
        id: holder

        anchors.fill: parent

        // Grows from the middle with the blob behind it rather than sliding in. Only while it is
        // coming in or out: a bubble opening on hover changes size, and scaling that as well would
        // have the content swim about inside it
        scale: 0.4 + 0.6 * root.prog
    }
}
