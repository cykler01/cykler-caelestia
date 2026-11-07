pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.modules.background
import qs.modules.dashboard.media

// --- Lyrics: the synced lines for whatever is playing, kept centred on the one being sung ---
//
// The engine is the same one the dashboard's media tab uses (services/lyrics), so the backend chosen in
// Settings › Services › Media & lyrics, the per-track offset and the cached lyrics all carry over. What is
// different is only the view: a few lines rather than the full pane, since a card has room for a few.
WidgetCard {
    id: lyrics

    // The same rule as the media card and the notch: whichever side is actually playing wins, and if neither
    // is, whichever paused most recently
    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
    readonly property MediaSource source: MediaSource {
        local: lyrics.local
        mpris: lyrics.local ? null : Players.recentPlayer
    }

    // The engine only knows the track a view hands it, so the track is pushed here whenever it changes. The
    // binding's value is never read: it exists so the assignment runs again as the track's own properties do,
    // which is the same trick the dashboard's lyric pane uses
    readonly property var trackBinding: {
        if (lyrics.source.available)
            Lyrics.setTrack(lyrics.source.artist, lyrics.source.title, lyrics.source.album, lyrics.source.length, lyrics.source.spotifyId);
        else
            Lyrics.clearTrack();
        return 0;
    }

    // A card is narrow enough that a word swept only as often as the player is polled would jump,
    // so the lines are placed from a clock that ticks between those readings
    readonly property LyricsClock clock: LyricsClock {
        source: lyrics.source
        wordTimed: Lyrics.wordTimed
    }

    // The line being sung, or -1 before the first one and while a track's lyrics haven't started
    readonly property int currentLine: Lyrics.hasLyrics ? Lyrics.indexForTime(lyrics.clock.position) : -1

    title: Tr.tr("Lyrics")
    icon: "lyrics"

    // MPRIS positions only move when asked, so without this the line would never advance. Paused playback
    // holds still, which costs nothing while the desktop is sitting there
    Timer {
        running: lyrics.source.isPlaying
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: lyrics.source.refresh()
    }

    // Which song the lines belong to, since the card sits away from the player
    StyledText {
        Layout.fillWidth: true
        visible: lyrics.source.available
        elide: Text.ElideRight
        text: lyrics.source.artist !== "" ? `${lyrics.source.title} · ${lyrics.source.artist}` : lyrics.source.title
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 64

        StyledText {
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: !lyrics.source.available
            text: Tr.tr("Nothing playing")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        // One line for both waits: the engine clears the lines it has while a fetch is out, so a card that
        // showed the old lines would be showing the previous song's words
        StyledText {
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: lyrics.source.available && !Lyrics.hasLyrics
            text: Lyrics.loading ? Tr.tr("Loading lyrics...") : Tr.tr("No lyrics found")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        // Scrolling the way the dashboard's lyric pane does: the sung line is held inside a band one line tall
        // around the middle, and moving the current index makes the view glide there over an animation
        // duration instead of snapping, which is what makes a line change read as one movement
        ListView {
            id: lines

            anchors.fill: parent
            visible: lyrics.source.available && Lyrics.hasLyrics
            clip: true
            // Nothing to drag through on a card: the view follows the song instead
            interactive: false
            spacing: Tokens.spacing.small
            model: Lyrics.lines

            currentIndex: lyrics.currentLine
            highlightRangeMode: ListView.ApplyRange
            highlightMoveDuration: Tokens.anim.durations.large
            highlightMoveVelocity: -1
            preferredHighlightBegin: (height - (currentItem?.implicitHeight ?? 0)) / 2
            preferredHighlightEnd: (height + (currentItem?.implicitHeight ?? 0)) / 2
            // The half-screen either side is enough for the lines that pass through while it glides
            displayMarginBeginning: height / 2
            displayMarginEnd: height / 2

            // A new song's lines arrive whole, so they are placed at once rather than animated in from the old
            // ones. Guarded because there is nothing to place before the first line is sung
            Component.onCompleted: {
                if (currentIndex >= 0 && count > 0)
                    positionViewAtIndex(currentIndex, ListView.Center);
            }
            onModelChanged: {
                if (currentIndex >= 0 && count > 0)
                    positionViewAtIndex(currentIndex, ListView.Center);
            }

            delegate: LyricLine {
                id: line

                required property var modelData
                required property int index

                width: lines.width
                line: modelData
                lineIndex: index
                time: lyrics.clock.position
                current: ListView.isCurrentItem
                // Centred, the way every other line on the card is
                center: true
                dim: Colours.palette.m3outline
                // Brightest text colour rather than the accent, so the sweep reads on a neutral
                // scheme too - see the note in modules/dashboard/media/LyricList.qml
                lit: Colours.palette.m3onSurface
                // 0 for the lines around it, 1 for the one being sung; the halo follows this, so
                // it fades in and out rather than switching on the change
                glow: ListView.isCurrentItem ? 1 : 0

                Behavior on glow {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }
        }
    }
}
