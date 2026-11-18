pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// The media card's strip: the cover as a square down the left, the track beside it and the controls
// riding on the same line as the position, so the whole player reads in one sweep of the eye
Item {
    id: root

    required property MediaSource source
    required property real progress

    implicitWidth: 260
    implicitHeight: 72

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        ClipRect {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: "album"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.large
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: root.source.available ? root.source.coverSource : ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: 0

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.source.available ? (root.source.title || Tr.tr("Unknown title")) : Tr.tr("Nothing playing")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.source.available ? (root.source.artist || Tr.tr("Unknown artist")) : Tr.tr("Play something in any app")
                color: root.source.available ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                font: Tokens.font.label.medium
            }

            Item {
                Layout.fillHeight: true
            }

            // The position shares a line with the buttons rather than taking one of its own, which is
            // what lets the strip stay three cells tall
            RowLayout {
                Layout.fillWidth: true
                visible: root.source.available
                spacing: Tokens.spacing.extraSmall

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.small
                    implicitHeight: 4
                    value: stripSeek.shown

                    SeekArea {
                        id: stripSeek

                        anchors.fill: parent
                        anchors.topMargin: -Tokens.spacing.small
                        anchors.bottomMargin: -Tokens.spacing.small
                        source: root.source
                        progress: root.progress
                    }
                }

                // Dropped on a narrow strip, where it would squeeze the position down to a stub
                IconButton {
                    visible: root.width > 340
                    icon: "skip_previous"
                    type: IconButton.Text
                    disabled: !root.source.canGoPrevious
                    onClicked: root.source.previous()
                }

                IconButton {
                    icon: root.source.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    onClicked: root.source.togglePlaying()
                }

                IconButton {
                    icon: "skip_next"
                    type: IconButton.Text
                    disabled: !root.source.canGoNext
                    onClicked: root.source.next()
                }
            }
        }
    }
}
