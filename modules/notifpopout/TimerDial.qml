pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the dial the countdown is set on. Drag the rim round to pick a length and tap the
// middle to type one - between them that is the whole of setting a timer, in place of the row of
// nudges and the grid of preset lengths that used to sit under it.
//
// One turn of the rim is an hour, snapped to the half minute, so the shortest thing it can be set
// to is thirty seconds rather than nothing at all. It does not wrap: dragging past the top holds
// at an hour rather than flipping back to nothing, which is the one thing that makes a dial like
// this unusable. Anything longer than an hour is typed in the middle, where the dial sits full.
Item {
    id: root

    // What is set, in seconds, and what the rim should be drawn at - the two differ while it runs,
    // where the rim empties as the time goes rather than showing what was set
    property int seconds
    property int shownSeconds: root.seconds

    property bool interactive: true
    property color accent: Colours.palette.m3primary

    // One turn of the rim, and the smallest step it snaps to
    readonly property int turnSeconds: 3600
    readonly property int stepSeconds: 30

    readonly property real cx: width / 2
    readonly property real cy: height / 2

    // Where the rim is drawn, 0 at the top and round clockwise
    readonly property real fill: Math.max(0, Math.min(1, root.shownSeconds / root.turnSeconds))
    // Where the handle sits: what is being dragged while a drag is in flight, so the handle keeps
    // up with the finger rather than with the eased rim behind it
    readonly property real handleAngle: (dragging ? dragAngle : root.fill * 360) - 90

    property bool dragging
    property real dragAngle

    // Anything inside this of the middle is the readout, not the rim
    readonly property real centreRadius: ring.arcRadius - ring.strokeWidth * 2

    default property alias content: centre.data

    signal moved(int secs)
    signal tapped

    // Where a point sits round the dial, 0 at the top and clockwise, in degrees
    function angleAt(x: real, y: real): real {
        const deg = Math.atan2(x - root.cx, root.cy - y) * 180 / Math.PI;
        return (deg + 360) % 360;
    }

    function distanceFrom(x: real, y: real): real {
        return Math.sqrt((x - root.cx) ** 2 + (y - root.cy) ** 2);
    }

    // The length an angle stands for. Anywhere off the top of the dial is at least one step, so
    // the shortest thing it can be set to is a useful length rather than nothing at all
    function secondsAt(angle: real): int {
        const raw = angle / 360 * root.turnSeconds;
        const snapped = Math.round(raw / root.stepSeconds) * root.stepSeconds;
        if (snapped <= 0)
            return angle > 0 ? root.stepSeconds : 0;
        return snapped;
    }

    CircularProgress {
        id: ring

        anchors.fill: parent

        strokeWidth: 12
        value: root.fill
        fgColour: root.accent
        bgColour: Colours.palette.m3surfaceContainerHighest
        // The grip below stands at the end of the arc already; the ring's own end dot sits at the
        // other end of it, where it reads as a speck of nothing at the top of the dial
        hasEndIndicator: false

        // Not while a drag is in flight: the rim has to sit under the finger, and easing it there
        // leaves it trailing behind the handle
        Behavior on clampedVal {
            enabled: !root.dragging

            Anim {}
        }
    }

    // The grip. It is always on the rim, and swells while it is being dragged so there is no doubt
    // what has hold of it
    StyledRect {
        id: handle

        readonly property real rad: root.handleAngle * Math.PI / 180

        x: root.cx + ring.arcRadius * Math.cos(handle.rad) - width / 2
        y: root.cy + ring.arcRadius * Math.sin(handle.rad) - height / 2

        visible: root.interactive
        implicitWidth: implicitHeight
        implicitHeight: ring.strokeWidth * (root.dragging ? 2 : 1.6)
        radius: Tokens.rounding.full
        color: root.accent
        scale: root.interactive ? 1 : 0

        Behavior on implicitHeight {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Item {
        id: centre

        anchors.centerIn: parent

        implicitWidth: root.centreRadius * 2
        implicitHeight: root.centreRadius * 2
    }

    // The rim takes the drag; the middle is left to whatever is drawn there, so tapping the
    // readout to type a time still works
    MouseArea {
        id: dragArea

        anchors.fill: parent

        enabled: root.interactive
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        onPressed: mouse => {
            if (root.distanceFrom(mouse.x, mouse.y) < root.centreRadius) {
                mouse.accepted = false;
                return;
            }

            root.dragAngle = root.angleAt(mouse.x, mouse.y);
            root.dragging = true;
            root.moved(root.secondsAt(root.dragAngle));
        }

        onPositionChanged: mouse => {
            if (!root.dragging)
                return;

            // Taken as a step from where the handle was rather than as an angle in its own right,
            // so a drag that crosses the top of the dial holds at either end instead of flipping
            // from an hour to nothing
            let delta = root.angleAt(mouse.x, mouse.y) - (root.dragAngle % 360 + 360) % 360;
            if (delta > 180)
                delta -= 360;
            else if (delta < -180)
                delta += 360;

            root.dragAngle = Math.max(0, Math.min(360, root.dragAngle + delta));
            root.moved(root.secondsAt(root.dragAngle));
        }

        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }
}
