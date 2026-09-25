import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property MediaSource source

    readonly property bool hasUnknownLength: root.source.length > 2147483647

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

    spacing: Tokens.spacing.extraSmall

    Timer {
        running: root.source.isPlaying
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.source.refresh()
    }

    StyledText {
        Layout.fillWidth: true
        text: root.source.title
        font: Tokens.font.title.large
        elide: Text.ElideRight
        animate: true
    }

    StyledText {
        Layout.fillWidth: true
        text: root.source.artist || Tr.tr("Unknown artist")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.title.medium
        elide: Text.ElideRight
        animate: true
    }

    StyledText {
        Layout.fillWidth: true
        text: root.source.album || Tr.tr("Unknown album")
        color: Colours.palette.m3secondary
        font: Tokens.font.title.medium
        elide: Text.ElideRight
        animate: true
    }

    RowLayout {
        Layout.topMargin: Tokens.spacing.extraLargeIncreased
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        TextMetrics {
            id: timeMetrics

            text: root.source.available ? root.lengthStr(Math.max(root.source.position, root.hasUnknownLength ? 0 : root.source.length)).replace(/[1-9]/g, "0") : "00:00"
            font: Tokens.font.label.medium
        }

        StyledText {
            id: positionLabel

            Layout.preferredWidth: timeMetrics.width
            text: root.lengthStr(root.source.available ? root.source.position : -1)
            color: Colours.palette.m3onSurfaceVariant
            font: timeMetrics.font
            horizontalAlignment: Text.AlignHCenter
        }

        StyledSlider {
            id: positionSlider

            Layout.fillWidth: true
            value: root.source.length > 0 ? root.source.position / root.source.length : 0
            enabled: root.source.canSeek && !root.hasUnknownLength
            wavy: true
            smoothValue: false
            // The wave scrolls at the screen's refresh rate for as long as it plays, so it holds still on battery
            animateWave: root.source.isPlaying && PowerSaving.animations && !PowerSaving.onBattery
            waveFrequency: 5
            waveDuration: 2000
            interactionOnMove: false
            onInteraction: value => root.source.seek(value * root.source.length)

            Binding {
                target: positionLabel
                property: "text"
                value: root.lengthStr(positionSlider.pos * root.source.length)
                when: positionSlider.dragging
            }
        }

        StyledText {
            Layout.preferredWidth: timeMetrics.width
            text: root.hasUnknownLength ? "--:--" : root.lengthStr(root.source.available ? root.source.length : -1)
            color: Colours.palette.m3onSurfaceVariant
            font: timeMetrics.font
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ButtonRow {
        Layout.topMargin: Tokens.spacing.largeIncreased
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        IconButton {
            type: IconButton.Tonal
            icon: "shuffle"
            isRound: true
            shapeMorph: true
            checked: root.source.shuffle
            font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
            disabled: !root.source.shuffleSupported
            onClicked: root.source.toggleShuffle()
            implicitWidth: Math.round(implicitHeight * 0.9)
        }

        IconButton {
            id: previousBtn

            type: IconButton.Tonal
            icon: "skip_previous"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.large
            disabled: !root.source.canGoPrevious
            onClicked: root.source.previous()
        }

        IconButton {
            id: playPauseBtn

            icon: root.source.isPlaying ? "pause" : "play_arrow"
            isRound: true
            shapeMorph: true
            fillWidth: true
            checked: root.source.isPlaying
            font: Tokens.font.icon.large
            disabled: !root.source.canTogglePlaying
            onClicked: root.source.togglePlaying()
        }

        IconButton {
            id: nextBtn

            type: IconButton.Tonal
            icon: "skip_next"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.large
            disabled: !root.source.canGoNext
            onClicked: root.source.next()
        }

        IconButton {
            type: IconButton.Tonal
            icon: root.source.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            isRound: true
            shapeMorph: true
            checked: root.source.loopState === MprisLoopState.Track || root.source.loopState === MprisLoopState.Playlist
            font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
            disabled: !root.source.loopSupported
            onClicked: root.source.cycleLoop()
            implicitWidth: Math.round(implicitHeight * 0.9)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        visible: root.source.volumeSupported
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: root.source.volume === 0 ? "volume_off" : "volume_up"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StyledSlider {
            Layout.fillWidth: true
            value: root.source.volume
            onInteraction: value => root.source.setVolume(value)
        }
    }
}
