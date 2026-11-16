pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.services
import qs.modules.dashboard.media

// The lyric card's highlighted lines: the line just sung, the one being sung and the one coming, set
// flush left against an accent mark. The mark stays put and the lines travel up past it, so the eye can
// rest on one spot and let the song come to it
Item {
    id: root

    required property MediaSource source
    required property real position
    required property int currentLine

    readonly property bool showLines: root.source.available && Lyrics.hasLyrics

    implicitWidth: 400
    implicitHeight: 110

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Which song the lines belong to
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "lyrics"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: root.source.available ? (root.source.artist !== "" ? `${root.source.title} · ${root.source.artist}` : root.source.title) : Tr.tr("Lyrics")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }

        Item {
            id: stage

            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Tokens.spacing.large
                visible: !root.showLines
                elide: Text.ElideRight
                text: {
                    if (!root.source.available)
                        return Tr.tr("Nothing playing");
                    return Lyrics.loading ? Tr.tr("Loading lyrics...") : Tr.tr("No lyrics found");
                }
                color: Colours.palette.m3outline
                font: Tokens.font.title.small
            }

            // The height of a sung line, for the band the view holds it in and the accent beside it
            StyledText {
                id: sungProbe

                visible: false
                text: "Ag"
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
            }

            // The accent the sung line lines up against
            StyledRect {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: sungProbe.implicitHeight - Tokens.spacing.extraSmall
                radius: width / 2
                color: Colours.palette.m3primary
                opacity: root.showLines && root.currentLine >= 0 ? 1 : 0.35

            }

            // Held so the sung line sits on the accent: the same scrolling as the default style's, with
            // the line the view is placed on drawn larger than the ones either side of it
            // Faded at both edges, so the lines either side trail off rather than being cut through
            VerticalFadeListView {
                id: lines

                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.large
                visible: root.showLines
                clip: true
                interactive: false
                fadeAmount: 0.1
                spacing: Tokens.spacing.extraSmall
                model: Lyrics.lines

                currentIndex: root.currentLine
                highlightRangeMode: ListView.ApplyRange
                highlightMoveDuration: PowerSaving.animations ? Tokens.anim.durations.large : 0
                highlightMoveVelocity: -1
                // Banded on the sung line's size taken from the type rather than from currentItem, whose own
                // height changes as it becomes current and would feed back into where the band is
                preferredHighlightBegin: (height - sungProbe.implicitHeight) / 2
                preferredHighlightEnd: (height + sungProbe.implicitHeight) / 2
                displayMarginBeginning: height / 2
                displayMarginEnd: height / 2

                Component.onCompleted: {
                    if (currentIndex >= 0 && count > 0)
                        positionViewAtIndex(currentIndex, ListView.Center);
                }
                onModelChanged: {
                    if (currentIndex >= 0 && count > 0)
                        positionViewAtIndex(currentIndex, ListView.Center);
                }

                delegate: LyricsSweep {
                    required property var modelData
                    required property int index

                    readonly property bool sung: index < root.currentLine

                    width: lines.width
                    line: modelData
                    lineIndex: index
                    time: root.position
                    current: ListView.isCurrentItem
                    fontBuilder: ListView.isCurrentItem ? Tokens.font.title.builders.medium.weight(Font.DemiBold) : Tokens.font.body.builders.medium
                    // The line just gone is quieter than the one coming, so the eye is pulled forward
                    dim: ListView.isCurrentItem ? Colours.palette.m3outline : sung ? Qt.alpha(Colours.palette.m3outline, 0.7) : Colours.palette.m3onSurfaceVariant
                    lit: Colours.palette.m3onSurface
                }
            }
        }
    }
}
