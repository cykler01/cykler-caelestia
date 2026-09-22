pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.images
import qs.services

// NOTE(fork): one tile of the media library gallery, either a folder or a track. Covers are
// rounded, a folder without a cover of its own shows a collage of its first tracks instead,
// and anything with no art at all falls back to a folder/music icon on a rounded placeholder.
// The size comes from the gallery, so a row with a couple of folders keeps them small.
Item {
    id: root

    required property FileSystemEntry entry
    // One cover, or four for a collage. Empty means there is nothing to show.
    property var covers: []
    property bool current
    property string subtitle

    readonly property bool useCollage: root.covers.length >= 4
    readonly property bool showIcon: root.covers.length === 0 || (!root.useCollage && image.status !== Image.Ready)

    signal clicked

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        StyledClippingRect {
            id: art

            Layout.fillWidth: true
            implicitHeight: width
            // A third of the tile, so the corners read as clearly rounded without the cover
            // turning into a circle (which would need half the tile).
            radius: Tokens.rounding.extraExtraLarge
            color: Colours.tPalette.m3surfaceContainer

            FadeImage {
                id: image

                anchors.fill: parent
                visible: root.covers.length > 0 && !root.useCollage
                source: root.covers.length > 0 ? root.covers[0] : ""
            }

            Item {
                id: collage

                readonly property real gap: Tokens.spacing.extraSmall / 2
                readonly property real cell: (width - gap) / 2

                anchors.fill: parent
                visible: root.useCollage

                Repeater {
                    model: root.covers.slice(0, 4)

                    FadeImage {
                        required property string modelData
                        required property int index

                        x: index % 2 === 0 ? 0 : collage.cell + collage.gap
                        y: index < 2 ? 0 : collage.cell + collage.gap
                        width: collage.cell
                        height: collage.cell
                        source: modelData
                    }
                }
            }

            MaterialShape {
                id: placeholder

                anchors.centerIn: parent
                implicitSize: Math.round(art.width * 0.5) || 1
                shape: MaterialShape.Cookie4Sided
                color: Colours.tPalette.m3surfaceContainerHighest
                opacity: root.showIcon ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.entry.isDir ? "folder" : "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.size(Math.round(placeholder.implicitSize * 0.5) || 1).build()
                }
            }

            // Drawn just inside the mask, so the ring isn't clipped by the rounded corners
            StyledRect {
                anchors.fill: parent

                visible: root.current
                radius: art.radius
                color: "transparent"
                border.width: 2
                border.color: Colours.palette.m3primary
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.entry.isDir ? root.entry.name : root.entry.baseName
            color: root.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.label.builders.small.weight(Font.Medium).build()
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
        }
    }

    StateLayer {
        onClicked: root.clicked()
    }
}
