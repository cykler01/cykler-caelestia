pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// One tile of the media library grid, either a folder or a track: a square of cover art with the
// name under it. A folder with no image of its own shows a 2x2 collage of the first tracks in it
// when there are four of them. Tapping opens a folder or plays a track (or ticks it, while the
// library is selecting); a track's own buttons appear over its art while it is hovered.
Item {
    id: root

    // The browser's row data, so both kinds of entry can share one tile
    required property var item
    property bool selecting
    property bool selected
    property bool current
    property bool playing

    readonly property bool isFolder: root.item.kind === "folder"
    readonly property var preview: root.item.preview ?? null
    readonly property var collage: root.isFolder && !(root.preview?.cover) && (root.preview?.tracks.length ?? 0) >= 4 ? root.preview.tracks : []
    readonly property bool selectable: root.selecting && !root.isFolder

    signal clicked
    signal playClicked
    signal enqueueClicked

    implicitHeight: art.height + Tokens.spacing.small + labels.implicitHeight

    ClipRect {
        id: art

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: width
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHighest

        CoverArt {
            anchors.fill: parent
            visible: root.collage.length === 0
            path: root.item.coverPath ?? ""
            fallback: root.item.coverFallback ?? ""
            fallbackFirst: root.isFolder
            icon: root.isFolder ? "folder" : "music_note"
            iconStyle: Tokens.font.icon.extraLarge
        }

        GridLayout {
            anchors.fill: parent
            visible: root.collage.length > 0
            columns: 2
            rowSpacing: 1
            columnSpacing: 1

            Repeater {
                model: root.collage

                CoverArt {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    path: modelData.path
                    fallback: modelData.fallback
                }
            }
        }

        // The current song, or the one being ticked
        StyledRect {
            anchors.fill: parent
            radius: art.radius
            color: "transparent"
            border.width: root.current || root.selected ? 2 : 0
            border.color: Colours.palette.m3primary
        }

        StateLayer {
            radius: art.radius
            onClicked: root.clicked()
        }

        // Says what a folder is when there is art on it, since it looks like a track otherwise
        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            visible: root.isFolder
            implicitWidth: folderIcon.implicitWidth + Tokens.padding.small
            implicitHeight: folderIcon.implicitHeight + Tokens.padding.small
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3scrim, 0.55)

            MaterialIcon {
                id: folderIcon

                anchors.centerIn: parent
                text: "folder"
                color: "white"
                fontStyle: Tokens.font.icon.small
                fill: 1
            }
        }

        MaterialIcon {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            visible: root.selectable || root.playing
            text: root.selectable ? (root.selected ? "check_circle" : "radio_button_unchecked") : "graphic_eq"
            color: root.selected || !root.selectable ? Colours.palette.m3primary : "white"
            fontStyle: Tokens.font.icon.medium
            fill: 1
        }

        // Play and queue, over the art while the pointer is on it
        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall
            visible: !root.isFolder && !root.selecting
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            IconButton {
                icon: "playlist_add"
                type: IconButton.Tonal
                onClicked: root.enqueueClicked()
            }

            IconButton {
                icon: "play_arrow"
                type: IconButton.Filled
                onClicked: root.playClicked()
            }
        }

        HoverHandler {
            id: hover
        }
    }

    ColumnLayout {
        id: labels

        anchors.top: art.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.item.name ?? ""
            color: root.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: (root.item.subtitle ?? "") !== ""
            text: root.item.subtitle ?? ""
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }
}
