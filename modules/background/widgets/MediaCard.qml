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

    // The cover variant puts the art across the top of the card with the name and controls under it, rather
    // than the art being a thumbnail beside the text
    readonly property bool cover: media.variant === "cover"
    // The newer styles each draw the whole card themselves (see the Media*.qml files beside this one),
    // so the two original layouts below only show for the variants they were written for
    readonly property string style: ["strip", "pill", "disc", "art"].includes(media.variant) ? media.variant : ""
    readonly property bool classic: media.style === ""

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
    // The newer styles carry no header: a strip or a pill has no room for one, and the disc and the
    // art are the picture first
    title: media.classic ? Tr.tr("Now playing") : ""
    icon: media.classic ? "music_note" : ""
    // The pill is a capsule all the way round, and the art runs to the card's edges
    radius: media.style === "pill" ? height / 2 : Tokens.rounding.extraLarge
    padding: {
        if (media.style === "art")
            return 0;
        if (media.style === "pill")
            return Tokens.padding.small;
        if (media.style === "strip")
            return Tokens.padding.medium;
        return Tokens.padding.largeIncreased;
    }

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
        visible: !media.source.available && media.classic
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
        visible: media.source.available && media.classic && !media.cover
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
        visible: media.source.available && media.classic && !media.cover
        spacing: Tokens.spacing.extraSmall

        StyledProgressBar {
            Layout.fillWidth: true
            implicitHeight: 4
            value: classicSeek.shown

            SeekArea {
                id: classicSeek

                anchors.fill: parent
                anchors.topMargin: -Tokens.spacing.small
                anchors.bottomMargin: -Tokens.spacing.small
                source: media.source
                progress: media.barValue
            }
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                // Where a drag or scroll would land while one is in progress
                text: media.lengthStr(classicSeek.preview >= 0 ? classicSeek.preview * media.source.length : media.source.position)
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

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: media.source.available && media.classic && media.cover
        spacing: Tokens.spacing.small

        // The art takes the top of the card, growing into whatever height the card was placed at
        ClipRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: "album"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.builders.extraLarge.build()
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: media.source.coverSource
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: media.source.title || Tr.tr("Unknown title")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: media.source.artist || Tr.tr("Unknown artist")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.medium

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

        StyledProgressBar {
            Layout.fillWidth: true
            implicitHeight: 4
            value: coverSeek.shown

            SeekArea {
                id: coverSeek

                anchors.fill: parent
                anchors.topMargin: -Tokens.spacing.small
                anchors.bottomMargin: -Tokens.spacing.small
                source: media.source
                progress: media.barValue
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: !media.classic
        visible: active

        sourceComponent: {
            switch (media.style) {
            case "strip":
                return stripStyle;
            case "pill":
                return pillStyle;
            case "disc":
                return discStyle;
            case "art":
                return artStyle;
            default:
                return null;
            }
        }
    }

    Component {
        id: stripStyle

        MediaStrip {
            source: media.source
            progress: media.barValue
        }
    }

    Component {
        id: pillStyle

        MediaPill {
            source: media.source
            progress: media.barValue
        }
    }

    Component {
        id: discStyle

        MediaDisc {
            source: media.source
            progress: media.barValue
        }
    }

    Component {
        id: artStyle

        MediaArt {
            source: media.source
            progress: media.barValue
            radius: media.radius
        }
    }
}
