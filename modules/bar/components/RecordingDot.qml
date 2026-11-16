pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): the notch's recording dot, drawn in the bar while the notch is not showing it - the
// same fallback the download ring takes (see modules/bar/components/DownloadRing.qml), and beside
// it. A red dot breathing while it records, swapped for a pause sign while it is paused. Pressing
// it opens the utilities panel, where the recorder's own card is.
StyledRect {
    id: root

    required property ScreenState screenState

    readonly property int size: Tokens.sizes.bar.innerWidth
    readonly property color accent: Recorder.paused ? Colours.palette.m3outline : Colours.palette.m3error

    implicitWidth: root.size
    implicitHeight: root.size

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    StyledRect {
        id: dot

        anchors.centerIn: parent

        visible: !Recorder.paused
        implicitWidth: Math.round(root.size * 0.4)
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        color: root.accent

        // Held steady when animations are switched off in Power & battery
        SequentialAnimation on opacity {
            running: Recorder.running && !Recorder.paused && PowerSaving.animations
            loops: Animation.Infinite

            onRunningChanged: {
                if (!running)
                    dot.opacity = 1;
            }

            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent

        visible: Recorder.paused
        text: "pause"
        color: root.accent
        fontStyle: Tokens.font.icon.small
    }

    StateLayer {
        radius: Tokens.rounding.full
        color: root.accent

        onClicked: root.screenState.utilities = true
    }
}
