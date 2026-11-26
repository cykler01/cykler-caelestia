pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.dashboard.media

// What's playing: the cover, the title over the artist, and the transport buttons beside them.
// The source is picked the same way the classic media widget picks it, the shell's own player
// and MPRIS alike. Hidden while nothing is playing or paused
Item {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
    readonly property MediaSource source: MediaSource {
        local: root.local
        mpris: root.local ? null : Players.recentPlayer
    }
    readonly property real artSize: 72 * root.s

    visible: (root.source.title ?? "") !== ""
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        spacing: Tokens.spacing.large * root.s

        StyledRect {
            visible: root.opts.art ?? true
            implicitWidth: root.artSize
            implicitHeight: root.artSize
            radius: Tokens.rounding.large * root.s
            color: Colours.tPalette.m3surfaceContainer
            clip: true

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
            }

            FadeImage {
                anchors.fill: parent
                source: root.source.coverSource
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
            }
        }

        ColumnLayout {
            spacing: Tokens.spacing.extraSmall * root.s

            StyledText {
                Layout.maximumWidth: 320 * root.s
                text: root.source.title || Tr.tr("Nothing playing")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                elide: Text.ElideRight
            }

            StyledText {
                Layout.maximumWidth: 320 * root.s
                text: root.source.artist ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.medium.scale(root.s).build()
                elide: Text.ElideRight
            }
        }

        RowLayout {
            visible: root.opts.controls ?? true
            spacing: Tokens.spacing.extraSmall * root.s

            Repeater {
                model: [
                    {
                        icon: "skip_previous",
                        act: () => root.source.previous(),
                        ok: root.source.canGoPrevious
                    },
                    {
                        icon: root.source.isPlaying ? "pause" : "play_arrow",
                        act: () => root.source.togglePlaying(),
                        ok: root.source.canTogglePlaying
                    },
                    {
                        icon: "skip_next",
                        act: () => root.source.next(),
                        ok: root.source.canGoNext
                    }
                ]

                StyledRect {
                    id: button

                    required property var modelData

                    implicitWidth: 40 * root.s
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: modelData.ok ? 1 : 0.4

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: button.modelData.icon
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.medium.scale(root.s).build()
                    }

                    StateLayer {
                        radius: button.radius
                        disabled: !button.modelData.ok
                        onClicked: button.modelData.act()
                    }
                }
            }
        }
    }
}
