pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets as Widgets
import qs.services
import qs.utils
import qs.modules.dashboard.media

Item {
    id: root

    // NOTE(fork): the in-shell local player is not an MPRIS player, so it never showed up here.
    // Whichever side is actually making sound right now wins outright; if neither is, both keep
    // what was last playing for a while after it pauses, and the one that stopped most recently
    // (Music.lastPlayedAt vs Players.rememberedAt) wins - the same rule the notch, lock screen and
    // desktop widget use to pick what to show.
    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
    readonly property MediaSource source: MediaSource {
        local: root.local
        mpris: root.local ? null : Players.recentPlayer
    }

    property real playerProgress: {
        const length = root.source.length;
        return length ? (root.source.position % length) / length : 0;
    }

    readonly property real arcCoverGap: Tokens.spacing.extraSmall

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Tokens.sizes.dashboard.mediaWidth

    Behavior on playerProgress {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Timer {
        running: root.source.isPlaying
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.source.refresh()
    }

    ServiceRef {
        service: PowerSaving.pauseVisualisers ? null : Audio.beatTracker
    }

    CircularProgress {
        id: prog

        anchors.centerIn: cover
        implicitSize: cover.width + root.arcCoverGap + thickness * 2

        fgColour: Colours.palette.m3primary
        strokeWidth: Tokens.sizes.dashboard.mediaProgressThickness
        startAngle: -90 - sweepAngle / 2
        sweepAngle: Tokens.sizes.dashboard.mediaProgressSweep
        value: root.playerProgress

        wavy: true
        waveFrequency: 8
        waveDuration: 2000
        wavePaused: !root.source.isPlaying
    }

    // Qualified: qs.modules.dashboard.media also exports a CoverArt (one based on a track's path),
    // and being imported after qs.components.widgets it would otherwise shadow the widgets one
    Widgets.CoverArt {
        id: cover

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium + root.arcCoverGap + prog.thickness
        implicitHeight: width

        source: root.source.coverSource
        spinning: root.source.isPlaying
    }

    StyledText {
        id: title

        anchors.top: cover.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.medium

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: root.source.available ? root.source.title || Tr.tr("Unknown title") : Tr.tr("No media")
        color: Colours.palette.m3primary
        font: Tokens.font.title.small

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    StyledText {
        id: album

        anchors.top: title.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: root.source.available ? root.source.album || Tr.tr("Unknown album") : Tr.tr("No media")
        color: Colours.palette.m3outline
        font: Tokens.font.body.small

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    StyledText {
        id: artist

        anchors.top: album.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: root.source.available ? root.source.artist || Tr.tr("Unknown artist") : Tr.tr("No media")
        color: Colours.palette.m3secondary

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    ButtonRow {
        id: controls

        anchors.top: artist.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.medium
        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.extraSmall

        IconButton {
            type: IconButton.Tonal
            icon: "skip_previous"
            isRound: true
            shapeMorph: true
            disabled: !root.source.canGoPrevious
            onClicked: root.source.previous()
        }

        IconButton {
            fillWidth: true
            icon: root.source.isPlaying ? "pause" : "play_arrow"
            isRound: true
            shapeMorph: true
            checked: root.source.isPlaying
            disabled: !root.source.canTogglePlaying
            onClicked: root.source.togglePlaying()
        }

        IconButton {
            type: IconButton.Tonal
            icon: "skip_next"
            isRound: true
            shapeMorph: true
            disabled: !root.source.canGoNext
            onClicked: root.source.next()
        }
    }

    AnimatedImage {
        id: bongocat

        anchors.top: controls.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.small
        anchors.bottomMargin: Tokens.padding.large
        anchors.margins: Tokens.padding.extraLargeIncreased

        playing: root.source.isPlaying
        speed: Audio.beatTracker.bpm / Config.general.mediaGifSpeedAdjustment // qmllint disable unresolved-type
        source: Paths.absolutePath(Config.paths.mediaGif)
        asynchronous: true
        fillMode: AnimatedImage.PreserveAspectFit
    }
}
