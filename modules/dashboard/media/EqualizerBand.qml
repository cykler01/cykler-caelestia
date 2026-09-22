import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): one band of the media tab's equalizer: a vertical slider whose middle is 0 dB,
// dragging or scrolling sets the gain. Reports the new gain as it moves so the service can push
// it into the running PipeWire node.
Item {
    id: root

    required property string label
    required property real gain
    property real maxGain: 12

    // The handle is deliberately wide and taller than the track: it is the part that gets grabbed,
    // so it should be a comfortable target rather than a bead on a line. Only the height counts
    // for the travel, so a wide handle still stops exactly at the top and bottom
    readonly property real knobWidth: 26
    readonly property real knobHeight: 16
    readonly property real knobTop: Math.round((0.5 - root.gain / (2 * root.maxGain)) * (root.height - root.knobHeight))
    readonly property real knobMiddle: root.knobTop + root.knobHeight / 2
    readonly property real zeroY: root.height / 2
    readonly property bool hovered: area.containsMouse

    signal moved(real gain)

    // Where the pointer is, in dB. The handle travels between the two ends of the track rather
    // than running off it, so the ends are reached with the pointer just inside the track and the
    // result is clamped to the range instead of overshooting it
    function gainAt(y: real): real {
        const travel = root.height - root.knobHeight;
        if (travel <= 0)
            return root.gain;

        const gain = (0.5 - (y - root.knobHeight / 2) / travel) * 2 * root.maxGain;
        return Math.max(-root.maxGain, Math.min(root.maxGain, gain));
    }

    implicitWidth: 44

    StyledRect {
        id: track

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Tokens.padding.extraSmall
        radius: width / 2
        color: Colours.tPalette.m3surfaceContainerHighest
    }

    // From 0 dB (the middle) to the knob, so the direction and size of the cut or boost reads at
    // a glance
    StyledRect {
        anchors.horizontalCenter: track.horizontalCenter
        width: track.width
        radius: track.radius
        color: Colours.palette.m3primary
        y: Math.min(root.zeroY, root.knobMiddle)
        height: Math.abs(root.knobMiddle - root.zeroY)
    }

    StyledRect {
        id: knob

        anchors.horizontalCenter: track.horizontalCenter
        y: root.knobTop
        width: root.knobWidth
        height: root.knobHeight
        // Half the height, so the handle reads as a pill like the track does
        radius: height / 2
        color: root.enabled ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest
        scale: area.pressed || root.hovered ? 1.15 : 1

        Behavior on scale {
            Anim {}
        }

        Behavior on y {
            enabled: !area.pressed

            Anim {}
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        // The whole column is the grab area, not just the handle, so a drag can be started
        // anywhere beside the track and the handle follows
        anchors.leftMargin: -Tokens.padding.large
        anchors.rightMargin: -Tokens.padding.large
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Clicking or dragging puts the knob where the pointer is, so grab and the knob follows
        onPressed: mouse => root.moved(root.gainAt(mouse.y))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.gainAt(mouse.y));
        }
        onWheel: wheel => root.moved(root.gain + (wheel.angleDelta.y > 0 ? 1 : -1))
    }
}
