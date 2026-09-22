pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Models
import qs.components
import qs.components.images
import qs.services

// NOTE(fork): one tile of the media library gallery, either a folder or a track. The album art
// is shown when the folder has any, and a folder/music icon stands in for it when it doesn't.
Item {
    id: root

    required property FileSystemEntry entry
    property string cover
    property bool current
    property string subtitle

    signal clicked

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        StyledClippingRect {
            id: art

            Layout.fillWidth: true
            implicitHeight: width
            radius: Tokens.rounding.largeIncreased
            color: Colours.tPalette.m3surfaceContainer

            FadeImage {
                id: image

                anchors.fill: parent
                source: root.cover
            }

            MaterialIcon {
                anchors.centerIn: parent

                text: root.entry.isDir ? "folder" : "music_note"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.size(Math.round(art.width * 0.3) || 1).build()
                opacity: image.status === Image.Ready ? 0 : 1
                animate: true

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
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
