pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The game library's featured style: the last game played across the whole card in its wide library art,
// with its name and a Play button on a scrim at the left, and the few played before it as small box art at
// the right to jump back into. The scrim is the card's own surface colour, so the text on it is the
// scheme's usual text colour in a light scheme as well as a dark one
Item {
    id: root

    required property var games
    // The card's corner, so the art is cut to the same curve as the plate under it
    property real radius: Tokens.rounding.extraLarge

    readonly property var lead: root.games[0] ?? null
    readonly property var others: root.games.slice(1, 4)

    implicitWidth: 380
    implicitHeight: 140

    ClipRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3surfaceContainerHigh

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.lead?.hero ?? ""
        }

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3surface, 0.94)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.alpha(Colours.palette.m3surface, 0.7)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3surface, 0.25)
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Tr.tr("Continue playing")
                color: Colours.palette.m3primary
                font: Tokens.font.label.builders.small.letterSpacing(1.2).weight(Font.DemiBold).capitalisation(Font.AllUppercase).build()
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                elide: Text.ElideRight
                text: root.lead?.name ?? ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.lead ? GameLibrary.lastPlayedText(root.lead.lastPlayed) : ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            Item {
                Layout.fillHeight: true
            }

            IconTextButton {
                icon: "play_arrow"
                text: Tr.tr("Play")
                type: TextButton.Filled
                onClicked: GameLibrary.launch(root.lead.appid)
            }
        }

        // The ones before it, smaller and sat on the same line as the button, so the eye takes the
        // featured game first
        RowLayout {
            Layout.alignment: Qt.AlignBottom
            spacing: Tokens.spacing.small

            Repeater {
                model: root.others

                GamesCover {
                    required property var modelData

                    Layout.preferredHeight: 78
                    Layout.preferredWidth: 52
                    game: modelData
                    radius: Tokens.rounding.small
                }
            }
        }
    }
}
