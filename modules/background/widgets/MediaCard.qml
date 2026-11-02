pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.background
import qs.modules.dashboard.media

// --- Now playing: the track from whichever player is making sound, or the one that stopped last ---
WidgetCard {
    id: media

    // Mirrors the notch's own rule: whichever side is actually playing right now wins, and if
    // neither is, whichever paused most recently (Music.lastPlayedAt vs Players.rememberedAt)
    // wins. This is the only widget that used to read Players.active directly, which is why it
    // never showed the in-shell player at all.
    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
    readonly property MediaSource source: MediaSource {
        local: media.local
        mpris: media.local ? null : Players.recentPlayer
    }

    readonly property bool unknownLength: media.source.length > 2147483647
    readonly property real barValue: media.source.length > 0 && !media.unknownLength ? Math.min(1, Math.max(0, media.source.position / media.source.length)) : 0

    // Minutes:seconds, growing to hours:minutes:seconds for a long track
    function lengthStr(length: real): string {
        if (length < 0)
            return "-1:-1";

        const hours = Math.floor(length / 3600);
        const mins = Math.floor((length % 3600) / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");

        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    // Always drawn, even with nothing to show: hiding the card left a grid cell that nothing painted,
    // which is what made it look broken while rearranging
    title: Tr.tr("Now playing")
    icon: "music_note"

    Timer {
        running: media.source.isPlaying
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: media.source.refresh()
    }

    // Nothing playing yet: a placeholder built from the card's own shapes, so an idle card still reads
    // as a player instead of as an empty plate
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 96
        visible: !media.source.available
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 64
            implicitHeight: 64
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.85)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

            MaterialIcon {
                anchors.centerIn: parent
                text: "album"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.builders.large.build()
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Tr.tr("Nothing playing")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Tr.tr("Play something in any app and it shows up here")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: media.source.available
        spacing: Tokens.spacing.medium

        ClipRect {
            implicitWidth: 76
            implicitHeight: 76
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: "album"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.large
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: media.source.coverSource
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: media.source.title || Tr.tr("Unknown title")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: media.source.artist || Tr.tr("Unknown artist")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            RowLayout {
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    icon: "skip_previous"
                    type: IconButton.Text
                    disabled: !media.source.canGoPrevious
                    onClicked: media.source.previous()
                }

                IconButton {
                    icon: media.source.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    onClicked: media.source.togglePlaying()
                }

                IconButton {
                    icon: "skip_next"
                    type: IconButton.Text
                    disabled: !media.source.canGoNext
                    onClicked: media.source.next()
                }
            }
        }
    }

    // Playback position: a bar across the card with the elapsed and total time under it
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.extraSmall
        visible: media.source.available
        spacing: Tokens.spacing.extraSmall

        StyledProgressBar {
            Layout.fillWidth: true
            implicitHeight: 4
            value: media.barValue
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: media.lengthStr(media.source.position)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: media.unknownLength ? "--:--" : media.lengthStr(media.source.length)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
