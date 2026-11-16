pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.modules.dashboard.media

// The lyric card's single line: the cover for context and the line being sung beside it in display type.
// A new line lifts in from below as the old one lifts away, so a change reads as the song moving on
// rather than as the text flickering
Item {
    id: root

    required property MediaSource source
    required property real position
    required property int currentLine

    // The line on screen. It trails currentLine by the length of the swap below, so the old line can
    // leave before the new one arrives
    property int shownLine: -1
    readonly property var shown: root.shownLine >= 0 ? (Lyrics.lines[root.shownLine] ?? null) : null
    // Read here rather than in the animations: tokens are looked up through the item they are used on,
    // and an animation is not one
    readonly property real liftBy: Tokens.spacing.small
    readonly property bool singing: root.source.available && Lyrics.hasLyrics && root.shown !== null

    implicitWidth: 400
    implicitHeight: 48

    Component.onCompleted: root.shownLine = root.currentLine
    onCurrentLineChanged: {
        if (root.currentLine === root.shownLine)
            return;
        swap.restart();
    }

    SequentialAnimation {
        id: swap

        ParallelAnimation {
            Anim {
                target: lineSlot
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                target: lift
                property: "y"
                to: -root.liftBy
                type: Anim.FastEffects
            }
        }
        ScriptAction {
            script: root.shownLine = root.currentLine
        }
        PropertyAction {
            target: lift
            property: "y"
            value: root.liftBy
        }
        ParallelAnimation {
            Anim {
                target: lineSlot
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
            Anim {
                target: lift
                property: "y"
                to: 0
                type: Anim.DefaultSpatial
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        ClipRect {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: Tokens.rounding.medium
            color: Colours.palette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: "lyrics"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: root.source.available ? root.source.coverSource : ""
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LyricsSweep {
                id: lineSlot

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.singing
                line: root.shown
                lineIndex: root.shownLine
                time: root.position
                current: true
                fontBuilder: Tokens.font.title.builders.large.weight(Font.DemiBold)

                transform: Translate {
                    id: lift
                }
            }

            // Everything that isn't a line being sung: what is playing, and why there is no line for it yet
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.singing
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.source.available ? (root.source.artist !== "" ? `${root.source.title} · ${root.source.artist}` : root.source.title) : Tr.tr("Nothing playing")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.large.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        if (!root.source.available)
                            return Tr.tr("Lyrics show up here while a song plays");
                        if (Lyrics.loading)
                            return Tr.tr("Loading lyrics...");
                        if (!Lyrics.hasLyrics)
                            return Tr.tr("No lyrics found");
                        return Tr.tr("Waiting for the first line");
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }
            }
        }
    }
}
