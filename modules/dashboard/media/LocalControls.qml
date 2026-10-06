pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services

// NOTE(fork): controls for the in-shell player alone, for the places that only ever play local
// files - the popout's library tab. A seek bar over transport buttons, then a volume slider:
// the position is read straight off the player, so it follows the song as it plays, and
// dragging it seeks (the elapsed time follows the drag and the seek happens on release, like
// the media tab's). Deliberately not the media tab's controls, which follow whichever source
// is active, MPRIS included: these keep driving the local queue even while a browser is the
// thing playing. The volume slider moves the player's own output volume (Music.volume), which
// is separate from the system sink's, so the music can be turned down without touching
// everything else. Everything is disabled rather than hidden with nothing queued, so the bar
// doesn't jump around as a queue appears.
ColumnLayout {
    id: root

    readonly property real length: Music.duration
    readonly property bool seekable: Music.hasTrack && root.length > 0
    // With nothing loaded there is no context to shuffle, so the shuffle button starts the
    // whole library off instead: a random song and the rest of the music folder dealt out
    // behind it. Only possible once the library has been read, which the tab does on opening.
    readonly property bool shuffleAll: !Music.hasTrack

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

    // Cover art and the current track's title/artist, above the transport controls - the
    // library list below already names each track, but nothing up here said what was actually
    // playing
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        spacing: Tokens.spacing.medium

        CoverArt {
            implicitWidth: 56
            implicitHeight: 56
            source: Music.coverPath
            spinning: Music.playing
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Music.hasTrack ? Music.title : Tr.tr("Nothing playing")
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: Music.hasTrack && Music.artist !== ""
                text: Music.artist
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }
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
            smoothValue: false
            animateWave: Music.playing && PowerSaving.animations && !PowerSaving.onBattery
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
            // With nothing open it shuffles the whole library, which needs something in it,
            // and otherwise shuffling a queue with one track in it does nothing - so the
            // button says so, but shuffle already on has to stay switchable off
            disabled: root.shuffleAll ? Music.library.length === 0 : (!Music.shuffle && Music.queue.length <= 1)
            onClicked: root.shuffleAll ? Music.shuffleAll() : Music.shuffle = !Music.shuffle
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

    // The player's own volume, not the system sink's: turning this down leaves everything
    // else at the level it was, and it persists on Music across tracks.
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        IconButton {
            type: IconButton.Tonal
            icon: Music.volume === 0 ? "volume_off" : "volume_up"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.small
            disabled: !Music.hasTrack
            onClicked: Music.setVolume(Music.volume > 0 ? 0 : 1)
        }

        StyledSlider {
            Layout.fillWidth: true
            value: Music.volume
            enabled: Music.hasTrack
            onInteraction: value => Music.setVolume(value)
        }
    }
}
