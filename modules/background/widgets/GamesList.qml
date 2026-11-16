pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

// The game library's list: a row per game with its art, its name and when it was last played, the last
// one played at the top. The whole row is the button, and a play mark comes up at its end on hover
Item {
    id: root

    required property var games

    implicitWidth: 260
    implicitHeight: 200

    VerticalFadeListView {
        id: rows

        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall
        clip: true
        model: root.games

        delegate: Item {
            id: row

            required property var modelData

            width: rows.width
            implicitHeight: 52

            StateLayer {
                id: touch

                radius: Tokens.rounding.medium
                color: Colours.palette.m3onSurface
                onClicked: GameLibrary.launch(row.modelData.appid)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.extraSmall
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.medium

                GamesCover {
                    Layout.preferredHeight: row.height - Tokens.padding.extraSmall
                    Layout.preferredWidth: Math.round((row.height - Tokens.padding.extraSmall) * 2 / 3)
                    game: row.modelData
                    radius: Tokens.rounding.small
                    interactive: false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: GameLibrary.lastPlayedText(row.modelData.lastPlayed)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }

                MaterialIcon {
                    text: "play_arrow"
                    color: Colours.palette.m3primary
                    fill: 1
                    fontStyle: Tokens.font.icon.medium
                    opacity: touch.containsMouse ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }
            }
        }
    }
}
