pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// NOTE(fork): one app's column in the utilities card's vertical layout: the level as a percentage,
// a vertical slider for it and the app's name. Reports the level as it moves so the card can write
// it to that stream, the way the horizontal row does.
ColumnLayout {
    id: root

    required property PwNode modelData

    readonly property real volume: root.modelData?.audio?.volume ?? 0
    readonly property real knobHeight: 10
    readonly property real knobTop: Math.round((1 - root.volume) * Math.max(0, trackArea.height - root.knobHeight))
    readonly property real knobMiddle: root.knobTop + root.knobHeight / 2

    signal moved(real volume)

    // Where the pointer is, as a level: the handle travels between the ends of the track rather
    // than running off it, so the ends are reached with the pointer just inside the track
    function volumeAt(y: real): real {
        const travel = trackArea.height - root.knobHeight;
        if (travel <= 0)
            return root.volume;
        return Math.max(0, Math.min(1, 1 - (y - root.knobHeight / 2) / travel));
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 40
    spacing: Tokens.spacing.extraSmall

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Strings.percentOne(root.volume)
        color: Colours.palette.m3primary
        font: Tokens.font.label.small
        animate: true
    }

    Item {
        id: trackArea

        Layout.fillWidth: true
        Layout.fillHeight: true

        StyledRect {
            id: track

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Tokens.padding.extraSmall
            radius: width / 2
            color: Colours.tPalette.m3surfaceContainerHighest
        }

        StyledRect {
            anchors.horizontalCenter: track.horizontalCenter
            width: track.width
            radius: track.radius
            color: Colours.palette.m3primary
            y: root.knobMiddle
            height: Math.max(0, trackArea.height - root.knobMiddle)
        }

        StyledRect {
            id: knob

            anchors.horizontalCenter: track.horizontalCenter
            y: root.knobTop
            width: 20
            height: root.knobHeight
            radius: height / 2
            color: root.enabled ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest
            scale: area.pressed || area.containsMouse ? 1.15 : 1

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
            anchors.leftMargin: -Tokens.spacing.small
            anchors.rightMargin: -Tokens.spacing.small
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => root.moved(root.volumeAt(mouse.y))
            onPositionChanged: mouse => {
                if (pressed)
                    root.moved(root.volumeAt(mouse.y));
            }
            onWheel: wheel => {
                const step = GlobalConfig.services.audioIncrement;
                root.moved(Math.max(0, Math.min(1, root.volume + (wheel.angleDelta.y > 0 ? step : -step))));
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: Audio.getStreamName(root.modelData)
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
        elide: Text.ElideRight
    }
}
