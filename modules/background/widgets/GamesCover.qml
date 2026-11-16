pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A game's portrait art from Steam's library cache, or its name on a plain tile for a game Steam has no art
// cached for. Clicking it starts the game; hovering it brings up a play mark, since the art alone doesn't
// say that it is a button
Item {
    id: root

    // One entry of GameLibrary.games
    required property var game
    property real radius: Tokens.rounding.medium
    // Off for the list's small thumbnails, where the row around them takes the hover and the click
    property bool interactive: true

    readonly property bool hovered: touch.containsMouse

    ClipRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3surfaceContainerHigh

        StyledText {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            visible: art.status !== Image.Ready
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            text: root.game.name
            color: Colours.palette.m3onSurfaceVariant
            font: root.width > 60 ? Tokens.font.label.medium : Tokens.font.label.small
        }

        Image {
            id: art

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.game.cover
            // The art is 600 x 900; nothing on a card draws it anywhere near that large
            sourceSize.width: 300
            scale: root.interactive && root.hovered ? 1.06 : 1

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.small
            visible: root.interactive
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: Colours.palette.m3primary
            opacity: root.hovered ? 1 : 0

            MaterialIcon {
                anchors.centerIn: parent
                text: "play_arrow"
                color: Colours.palette.m3onPrimary
                fill: 1
                fontStyle: Tokens.font.icon.medium
            }

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }

    StateLayer {
        id: touch

        visible: root.interactive
        radius: root.radius
        color: Colours.palette.m3onSurface
        onClicked: GameLibrary.launch(root.game.appid)
    }
}
