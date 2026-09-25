pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.services

// NOTE(fork): one row of the media library list, either a folder or a track. The cover stays
// small and square so a few hundred tracks read as a list rather than a wall of artwork, and a
// row with no art of its own falls back to an icon on a rounded placeholder. The whole row is
// the button, and while the library is selecting it carries a checkbox and toggles instead of
// playing.
//
// A track also carries its own two buttons: play it now, or put it on the end of the queue
// behind whatever is playing. In the queue view the same row carries a grip it can be dragged
// by, and a button to take it out of the queue or out of the history.
Item {
    id: root

    // The browser's row data, so both kinds of entry can share one row
    required property var item
    // Whether the library is collecting tracks into a selection
    property bool selecting
    property bool selected
    // Whether this row is a song in the queue view that can be dragged to reorder it
    property bool reorderable
    // ...and whether it can be taken out of the queue or out of the history
    property bool removable
    // Whether this row is the song playing now, and whether it is actually playing. Both fall
    // back to what the row data says, which is what the queue view passes in; the library
    // builds its rows once and hands the live state over instead, so a track changing or
    // playback being toggled does not rebuild the whole list.
    property bool current: root.item.current === true
    property bool playing: root.item.playing === true

    // The queue view puts section headers through this row too, with none of a song's fields,
    // so everything that reads one of them falls back to an empty value
    readonly property bool showingCover: (root.item.cover ?? "") !== "" && image.status !== Image.Error
    // Only tracks can be queued, so a folder has nothing to tick
    readonly property bool selectable: root.selecting && root.item.kind === "track"
    // The row's own actions only apply to something that can be played on its own
    readonly property bool actionsShown: root.item.kind === "track" && !root.selecting && !root.reorderable && !root.removable

    signal clicked
    signal playClicked
    signal enqueueClicked
    signal removeClicked

    implicitHeight: Math.max(cover.implicitHeight, layout.implicitHeight) + Tokens.padding.small * 2

    StyledRect {
        id: bg

        anchors.fill: parent
        color: root.current ? Colours.palette.m3secondaryContainer : root.selected ? Qt.alpha(Colours.palette.m3primary, 0.16) : "transparent"
        radius: Tokens.rounding.medium

        // Under the content rather than over it, so the row's own buttons get their click and
        // everything else falls through to here - which is what plays the track
        StateLayer {
            id: layer

            onClicked: root.clicked()
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.medium

            StyledClippingRect {
                id: cover

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 40
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHighest

                FadeImage {
                    id: image

                    anchors.fill: parent
                    visible: root.showingCover
                    source: root.item.cover ?? ""
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.showingCover
                    text: root.item.kind === "folder" ? "folder" : "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.item.name ?? ""
                    color: root.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (root.item.subtitle ?? "") !== ""
                    text: root.item.subtitle ?? ""
                    color: root.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideMiddle
                }
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.playing
                text: "graphic_eq"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.selectable
                text: root.selected ? "check_box" : "check_box_outline_blank"
                color: root.selected ? Colours.palette.m3primary : Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }

            // Grip to drag the row by, up and down the queue
            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.reorderable
                text: "drag_indicator"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }

            // Out of the queue, or out of the history
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                visible: root.removable
                icon: "delete"
                type: IconButton.Text
                onClicked: root.removeClicked()
            }

            // Play this one, or line it up behind what is already playing
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                visible: root.actionsShown
                icon: "play_arrow"
                type: IconButton.Text
                onClicked: root.playClicked()
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                visible: root.actionsShown
                icon: "playlist_add"
                type: IconButton.Text
                onClicked: root.enqueueClicked()
            }
        }
    }
}
