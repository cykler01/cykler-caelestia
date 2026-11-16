pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The game library's shelf: the games' box art standing in a row, the last one played at the left. The
// row scrolls sideways for a library longer than the card, and the name and when it was last played of
// whichever game is under the pointer show under the row, so the art can fill the height
Item {
    id: root

    required property var games

    // The game the line under the shelf talks about: the one hovered, or the last one played
    property var focused: null
    readonly property var shown: root.focused ?? root.games[0] ?? null

    implicitWidth: 400
    implicitHeight: 180

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        ListView {
            id: shelf

            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: Tokens.spacing.small
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.games

            delegate: GamesCover {
                id: cover

                required property var modelData

                game: modelData
                width: Math.round(shelf.height * 2 / 3)
                height: shelf.height
                onHoveredChanged: {
                    if (hovered)
                        root.focused = cover.modelData;
                    else if (root.focused === cover.modelData)
                        root.focused = null;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: root.shown?.name ?? ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                text: root.shown ? GameLibrary.lastPlayedText(root.shown.lastPlayed) : ""
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
