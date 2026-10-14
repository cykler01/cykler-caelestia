pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Analogue alternative to the digital readout (center/Clock.qml), shown when
// Config.lock.analogueClock is on - a full dial with hour and minute hands, sized off the
// same centerScale the digital clock's fonts use so it keeps the centre column's proportions.
// Built from plain rotated items rather than a Canvas: hands and ticks are live bindings, and
// everything scales cleanly under the settings preview's scale-down transform, which a Canvas
// paints at its own fixed buffer size and renders wrong under
Item {
    id: root

    required property real centerScale

    // Angles in degrees, 12 o'clock at 0 and increasing clockwise; the minutes are fractioned
    // in so the hands glide continuously instead of snapping on the tick
    readonly property real hourAngle: (Time.hours % 12 + Time.minutes / 60 + Time.seconds / 3600) * 30
    readonly property real minuteAngle: (Time.minutes + Time.seconds / 60) * 6

    readonly property real dialSize: 220 * root.centerScale
    readonly property real faceRadius: dialSize / 2 - Tokens.padding.small * root.centerScale

    implicitWidth: dialSize
    implicitHeight: dialSize

    // Hour ticks: quarter markers drawn bold and opaque, the rest faint
    Repeater {
        model: 12

        Item {
            id: tick

            required property int index

            readonly property bool major: index % 3 === 0
            readonly property real len: (major ? 0.16 : 0.08) * root.faceRadius

            anchors.fill: parent
            rotation: index * 30

            StyledRect {
                width: (tick.major ? 3 : 2) * root.centerScale
                height: tick.len
                radius: width / 2

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dialSize / 2 - root.faceRadius
                color: Qt.alpha(Colours.palette.m3onSurface, tick.major ? 1 : 0.3)
            }
        }
    }

    // Minute hand - longer, lighter
    Item {
        anchors.fill: parent
        rotation: root.minuteAngle

        StyledRect {
            width: 4 * root.centerScale
            height: root.faceRadius * 0.9
            radius: width / 2

            anchors.horizontalCenter: parent.horizontalCenter
            // Growing upward from the dial's centre line, so the wrapper's rotation pivots it
            // around the dial centre with the hand always pointing out along its angle
            anchors.bottom: parent.verticalCenter
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // Hour hand - shorter, heavier
    Item {
        anchors.fill: parent
        rotation: root.hourAngle

        StyledRect {
            width: 6 * root.centerScale
            height: root.faceRadius * 0.55
            radius: width / 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            color: Colours.palette.m3onSurface
        }
    }

    StyledRect {
        anchors.centerIn: parent
        width: 8 * root.centerScale
        height: width
        radius: width / 2
        color: Colours.palette.m3primary
    }
}
