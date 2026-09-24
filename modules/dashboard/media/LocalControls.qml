pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): controls for the in-shell player alone, for the places that only ever play local
// files - the popout's library tab. A seek bar over transport buttons: the position is read
// straight off the player, so it follows the song as it plays, and dragging it seeks (the
// elapsed time follows the drag and the seek happens on release, like the media tab's).
// Deliberately not the media tab's controls, which follow whichever source is active, MPRIS
// included: these keep driving the local queue even while a browser is the thing playing.
// Everything is disabled rather than hidden with nothing queued, so the bar doesn't jump
// around as a queue appears.
ColumnLayout {
    id: root

    readonly property real length: Music.duration
    readonly property bool seekable: Music.hasTrack && root.length > 0

    spacing: Tokens.spacing.small

    function timeStr(seconds: real): string {
        if (!(seconds >= 0) || seconds > 2147483647)
            return "--:--";

        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60).toString().padStart(2, "0");
        if (mins < 60)
            return `${mins}:${secs}`;

        const hours = Math.floor(mins / 60);
        return `${hours}:${(mins % 60).toString().padStart(2, "0")}:${secs}`;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        // Digits at the width the longest time this track can reach takes, so the slider
        // doesn't get shoved around as the elapsed time ticks over
        TextMetrics {
            id: timeMetrics

            text: root.seekable ? root.timeStr(root.length).replace(/[0-9]/g, "0") : "00:00"
            font: Tokens.font.label.medium
        }

        StyledText {
            id: positionLabel

            Layout.preferredWidth: timeMetrics.width
            text: root.seekable ? root.timeStr(Music.position) : "--:--"
            color: Colours.palette.m3onSurfaceVariant
            font: timeMetrics.font
            horizontalAlignment: Text.AlignHCenter
        }

        StyledSlider {
            id: seekSlider

            Layout.fillWidth: true
            value: root.seekable ? Music.position / root.length : 0
            enabled: root.seekable
            wavy: true
            animateWave: Music.playing
            waveFrequency: 5
            waveDuration: 2000
            interactionOnMove: false
            onInteraction: value => Music.seek(value * root.length)

            // While dragging, the elapsed time shows where the handle is rather than where
            // the song is
            Binding {
                target: positionLabel
                property: "text"
                value: root.timeStr(seekSlider.pos * root.length)
                when: seekSlider.dragging
            }
        }

        StyledText {
            Layout.preferredWidth: timeMetrics.width
            text: root.seekable ? root.timeStr(root.length) : "--:--"
            color: Colours.palette.m3onSurfaceVariant
            font: timeMetrics.font
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ButtonRow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        IconButton {
            type: IconButton.Tonal
            icon: "shuffle"
            isRound: true
            shapeMorph: true
            checked: Music.shuffle
            font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
            // Shuffling a queue with one track in it does nothing, so the button says so
            disabled: Music.queue.length <= 1
            onClicked: Music.shuffle = !Music.shuffle
            implicitWidth: Math.round(implicitHeight * 0.9)
        }

        IconButton {
            type: IconButton.Tonal
            icon: "skip_previous"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.large
            // The history is behind it, so this works with nothing playing too
            disabled: !Music.hasTrack && Music.played.length === 0
            onClicked: Music.previous()
        }

        IconButton {
            icon: Music.playing ? "pause" : "play_arrow"
            isRound: true
            shapeMorph: true
            fillWidth: true
            checked: Music.playing
            font: Tokens.font.icon.large
            disabled: !Music.hasTrack
            onClicked: Music.togglePlaying()
        }

        IconButton {
            type: IconButton.Tonal
            icon: "skip_next"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.large
            // Nothing left to move on to, unless the repeat is going round again
            disabled: !Music.hasTrack || (Music.queue.length === 0 && Music.repeatMode !== "all")
            onClicked: Music.next()
        }

        IconButton {
            type: IconButton.Tonal
            icon: Music.repeatMode === "one" ? "repeat_one" : "repeat"
            isRound: true
            shapeMorph: true
            checked: Music.repeatMode !== "off"
            font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
            onClicked: Music.cycleRepeat()
            implicitWidth: Math.round(implicitHeight * 0.9)
        }
    }
}
