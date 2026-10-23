import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.modules.dashboard.media
import qs.services

ClipRect {
    id: root

    required property var lock

    // NOTE(fork): the in-shell local player is not an MPRIS player, so it never showed up here.
    // Whichever side is actually making sound right now wins outright; if neither is, both keep
    // what was last playing for a while after it pauses, and the one that stopped most recently
    // (Music.lastPlayedAt vs Players.rememberedAt) wins - the same rule the notch and the desktop
    // widget use to pick what to show.
    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
    readonly property MediaSource source: MediaSource {
        local: root.local
        mpris: root.local ? null : Players.recentPlayer
    }

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    FadeImage {
        anchors.fill: parent
        source: root.source.coverSource

        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: {
            const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
            return Qt.size(width * dpr, height * dpr);
        }

        layer.enabled: true

        // FadeImage fades itself in once loaded (and re-fades on a source change) - an opacity
        // binding/Behavior here would fight that internal animation over the same property and
        // could leave it stuck invisible, so the dimming overlay is all that's added on top
        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3surface
            opacity: 0.7
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: root.source.title || Tr.tr("Nothing playing")
            color: Colours.palette.m3primary
            horizontalAlignment: Text.AlignHCenter
            font: Tokens.font.title.medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: root.source.artist || Tr.tr("Try playing some music!")
            color: Colours.palette.m3onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium

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
                icon: root.source.isPlaying ? "pause" : "play_arrow"
                isRound: true
                shapeMorph: true
                checked: root.source.isPlaying
                disabled: !root.source.canTogglePlaying
                onClicked: root.source.togglePlaying()
                implicitWidth: implicitHeight + Tokens.padding.largeIncreased * 2
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
    }
}
