pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

// NOTE(fork): one row of the media library list, either a folder, an artist's playlist or a
// track. The cover stays small and square so a few hundred tracks read as a list rather than
// a wall of artwork, and a row with no art of its own falls back to an icon on a rounded
// placeholder. The whole row is the button, and while the library is selecting it carries a
// checkbox and toggles instead of playing.
Item {
    id: root

    // The browser's row data, so all three kinds of entry can share one row
    required property var item
    // Whether the library is collecting tracks into a selection
    property bool selecting
    property bool selected

    readonly property bool showingCover: root.item.cover !== "" && image.status !== Image.Error
    // Only tracks can be queued, so a folder or an artist has nothing to tick
    readonly property bool selectable: root.selecting && root.item.kind === "track"

    signal clicked

    implicitHeight: Math.max(cover.implicitHeight, layout.implicitHeight) + Tokens.padding.small * 2

    StyledRect {
        id: bg

        anchors.fill: parent
        color: root.item.current ? Colours.palette.m3secondaryContainer : root.selected ? Qt.alpha(Colours.palette.m3primary, 0.16) : "transparent"
        radius: Tokens.rounding.medium

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.medium
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
                    source: root.item.cover
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.showingCover
                    text: root.item.kind === "folder" ? "folder" : root.item.kind === "artist" ? "person" : "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.item.name
                    color: root.item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.item.subtitle !== ""
                    text: root.item.subtitle
                    color: root.item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideMiddle
                }
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.item.playing
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
        }

        StateLayer {
            onClicked: root.clicked()
        }
    }
}
