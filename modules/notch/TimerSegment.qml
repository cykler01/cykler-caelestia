pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the running countdown, drawn inside a Bubble: a ring filling as the time goes, with
// what is left of it in the middle. It reads the shell's one countdown (services/CountdownTimer.qml),
// so a timer started anywhere - the utilities panel, the sidebar's timer pane - shows up here.
//
// Colours follow the bar's own ring (modules/bar/components/TimerRing.qml): primary while it
// counts, outline while it is paused, tertiary once it has rung.
Item {
    id: root

    readonly property color accent: CountdownTimer.finished ? Colours.palette.m3tertiary : CountdownTimer.running ? Colours.palette.m3primary : Colours.palette.m3outline

    CircularProgress {
        id: ring

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        strokeWidth: Math.max(3, Math.round(width / 12))
        value: CountdownTimer.progress
        fgColour: root.accent
        bgColour: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
    }

    // No fade on change: this reads a new value every second, and a crossfade per tick would be a
    // redraw loop for nothing
    StyledText {
        anchors.centerIn: parent

        visible: !CountdownTimer.finished
        width: ring.width - ring.strokeWidth * 3
        horizontalAlignment: Text.AlignHCenter
        text: CountdownTimer.display
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.medium
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
    }

    MaterialIcon {
        anchors.centerIn: parent

        visible: CountdownTimer.finished
        text: "alarm"
        color: root.accent
        fontStyle: Tokens.font.icon.small
    }
}
