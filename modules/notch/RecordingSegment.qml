pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): a screen recording in progress, drawn inside a Bubble beside the download one. It
// reads the shell's one recorder (services/Recorder.qml), so a recording started from a keybind
// shows up here as well as one started from the utilities panel.
//
// The circle is the usual red recording dot, breathing while it records and swapped for a pause
// sign while it is paused. Hovering opens the bubble out for how long it has been going, and the
// buttons to pause and stop it without opening the utilities panel.
Item {
    id: root

    // How far the bubble has opened, and which way it opened
    property real expandProg
    property bool mirrored

    // What the bubble has to grow by to fit the detail
    readonly property real detailWidth: detail.implicitWidth

    readonly property color accent: Recorder.paused ? Colours.palette.m3outline : Colours.palette.m3error

    // The text only arrives once there is room for it, so it is never drawn squashed
    readonly property real textProg: Math.max(0, Math.min(1, (root.expandProg - 0.4) / 0.6))

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

        StyledRect {
            id: dot

            anchors.centerIn: parent

            visible: !Recorder.paused
            implicitWidth: Math.round(circle.height * 0.36)
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: root.accent

            // Breathes while it records, the way a camera's light does. Held steady when animations
            // are switched off in Power & battery
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

        // Pressing the circle opens the panel the recorder lives in. It sits on the circle rather
        // than on the whole bubble so it cannot end up fighting the buttons for the press
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
                    text: Tr.tr("Screen recording")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.large
                }

                StyledText {
                    text: Recorder.paused ? Tr.tr("Paused at %1").arg(Recorder.elapsedDisplay) : Recorder.elapsedDisplay
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.mono.small
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter

                icon: Recorder.paused ? "play_arrow" : "pause"
                type: IconButton.Text
                padding: Tokens.padding.extraSmall / 2
                font: Tokens.font.icon.small
                onClicked: Recorder.togglePause()
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter

                icon: "stop"
                type: IconButton.Text
                padding: Tokens.padding.extraSmall / 2
                font: Tokens.font.icon.small
                onClicked: Recorder.stop()
            }

            // Tucks the bubble away, leaving the recording running with only a mark on the pill to
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
