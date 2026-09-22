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

    readonly property real knobSize: 13
    readonly property real knobTop: Math.round((0.5 - root.gain / (2 * root.maxGain)) * (root.height - root.knobSize))
    readonly property real knobMiddle: root.knobTop + root.knobSize / 2
    readonly property real zeroY: root.height / 2
    readonly property bool hovered: area.containsMouse

    signal moved(real gain)

    function gainAt(y: real): real {
        const travel = root.height - root.knobSize;
        if (travel <= 0)
            return root.gain;
        return (0.5 - (y - root.knobSize / 2) / travel) * 2 * root.maxGain;
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
        width: root.knobSize
        height: root.knobSize
        radius: Tokens.rounding.extraSmall
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
        anchors.leftMargin: -Tokens.padding.small
        anchors.rightMargin: -Tokens.padding.small
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
