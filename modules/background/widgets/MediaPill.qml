pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// The media card's pill: a round thumbnail, the track, and one button. The position runs round that
// button as a ring instead of along a bar, since a capsule this short has no line to spare for one
Item {
    id: root

    required property MediaSource source
    required property real progress

    implicitWidth: 300
    implicitHeight: 56

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        ClipRect {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: height / 2
            color: Colours.palette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.source.available ? (root.source.title || Tr.tr("Unknown title")) : Tr.tr("Nothing playing")
                color: root.source.available ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.source.available
                elide: Text.ElideRight
                text: root.source.artist || Tr.tr("Unknown artist")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            Layout.rightMargin: Tokens.spacing.extraSmall
            visible: root.source.available

            CircularProgress {
                anchors.fill: parent
                value: root.progress
                strokeWidth: 3
                spacing: Tokens.spacing.extraSmall
                fgColour: Colours.palette.m3primary
                bgColour: Qt.alpha(Colours.palette.m3secondaryContainer, 0.7)
            }

            // Drawn rather than an IconButton, so it can be sized to sit inside the ring with a gap
            StyledRect {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.66)
                height: width
                radius: width / 2
                color: Colours.palette.m3primary

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.source.isPlaying ? "pause" : "play_arrow"
                    color: Colours.palette.m3onPrimary
                    fill: 1
                    fontStyle: Tokens.font.icon.medium
                }

                StateLayer {
                    radius: width / 2
                    color: Colours.palette.m3onPrimary
                    disabled: !root.source.canTogglePlaying
                    onClicked: root.source.togglePlaying()
                }
            }
        }
    }
}
