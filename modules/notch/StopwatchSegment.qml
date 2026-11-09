pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the stopwatch, drawn inside a Bubble beside the countdown's one. It reads the
// shell's one stopwatch (services/Stopwatch.qml), so one started in the timer panel shows up here.
//
// A count with no end has no progress to fill a ring with, so the ring sweeps the minute it is in
// instead - which reads as a second hand going round, and says at a glance that it is still going.
// Hovering opens the bubble out for the hundredths and the laps, which the circle has no room for.
Item {
    id: root

    // How far the bubble has opened, and which way it opened
    property real expandProg
    property bool mirrored

    // What the bubble has to grow by to fit the detail
    readonly property real detailWidth: detail.implicitWidth

    readonly property color accent: Stopwatch.running ? Colours.palette.m3tertiary : Colours.palette.m3outline

    // The text only arrives once there is room for it, so it is never drawn squashed
    readonly property real textProg: Math.max(0, Math.min(1, (root.expandProg - 0.4) / 0.6))

    readonly property string status: {
        if (!Stopwatch.running)
            return Tr.tr("Stopped at %1").arg(Stopwatch.display);
        if (Stopwatch.laps.length > 0)
            // TRANSLATORS: %1 = a lap number, %2 = how long that lap has been running
            return Tr.tr("Lap %1 · %2").arg(Stopwatch.laps.length + 1).arg(Stopwatch.format(Stopwatch.currentSplit));
        return Stopwatch.display;
    }

    signal dismissed
    signal activated

    // The circle itself, at the end the bubble grew from so it stays put as the detail opens out
    Item {
        id: circle

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.mirrored ? undefined : parent.left
        anchors.right: root.mirrored ? parent.right : undefined

        implicitWidth: height

        CircularProgress {
            id: ring

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            strokeWidth: Math.max(3, Math.round(width / 12))
            value: Stopwatch.minuteProgress
            fgColour: root.accent
            bgColour: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
        }

        // No fade on change: this reads a new value every second, and a crossfade per tick would be
        // a redraw loop for nothing
        StyledText {
            anchors.centerIn: parent

            width: ring.width - ring.strokeWidth * 3
            horizontalAlignment: Text.AlignHCenter
            text: Stopwatch.shortDisplay
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
        }

        // Pressing the ring opens the panel it is set in. It sits on the ring rather than on the
        // whole bubble so it cannot end up fighting the dismiss button for the press
        StateLayer {
            radius: Tokens.rounding.full
            color: root.accent

            onClicked: root.activated()
        }
    }

    // What the circle has no room for, uncovered as the bubble opens
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.mirrored ? parent.left : circle.right
        anchors.right: root.mirrored ? circle.left : parent.right

        visible: root.expandProg > 0.001
        clip: true

        RowLayout {
            id: detail

            // The bubble on the notch's left is a mirror image of the one on its right, so what
            // sits at the far end of one sits at the far end of the other
            LayoutMirroring.enabled: root.mirrored
            LayoutMirroring.childrenInherit: true

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.mirrored ? undefined : parent.left
            anchors.right: root.mirrored ? parent.right : undefined
            anchors.leftMargin: root.mirrored ? 0 : Tokens.spacing.small
            anchors.rightMargin: root.mirrored ? Tokens.spacing.small : 0

            opacity: root.textProg
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter

                spacing: 0

                StyledText {
                    text: Tr.tr("Stopwatch")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.large
                }

                StyledText {
                    text: root.status
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.mono.small
                }
            }

            // Tucks the bubble away, leaving the stopwatch running with only a mark on the pill to
            // say so (see Pill.qml)
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Tokens.spacing.extraSmall

                icon: "close"
                type: IconButton.Text
                padding: Tokens.padding.extraSmall / 2
                font: Tokens.font.icon.small
                onClicked: root.dismissed()
            }
        }
    }
}
