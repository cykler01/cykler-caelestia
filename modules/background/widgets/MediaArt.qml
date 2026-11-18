pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// The media card's art: the cover runs to the card's edges and everything else sits on a scrim across
// its foot. The scrim is drawn from the card's own surface colour rather than black, so the text on it
// is the scheme's usual text colour and reads the same way in a light scheme as in a dark one
Item {
    id: root

    required property MediaSource source
    required property real progress
    // The card's corner, so the art is cut to the same curve as the plate under it
    property real radius: Tokens.rounding.extraLarge

    // Minutes:seconds, the same as the player's other styles
    function timeStr(length: real): string {
        if (length < 0 || isNaN(length))
            return "0:00";
        const mins = Math.floor(length / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");
        return `${mins}:${secs}`;
    }

    implicitWidth: 200
    implicitHeight: 200

    ClipRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3surfaceContainerHigh

        MaterialIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.source.available ? -Tokens.spacing.extraLarge : -Tokens.spacing.large
            text: "album"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build()
        }

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.source.available ? root.source.coverSource : ""
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.62

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3surface, 0)
                }
                GradientStop {
                    position: 0.45
                    color: Qt.alpha(Colours.palette.m3surface, 0.72)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3surface, 0.94)
                }
            }
        }

        // The position, as a hairline along the very foot of the card
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            visible: root.source.available
            width: parent.width * artSeek.shown
            height: 3
            color: Colours.palette.m3primary
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large
        anchors.bottomMargin: Tokens.padding.large - Tokens.spacing.extraSmall
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.source.available ? (root.source.title || Tr.tr("Unknown title")) : Tr.tr("Nothing playing")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.source.available ? (root.source.artist || Tr.tr("Unknown artist")) : Tr.tr("Play something in any app")
            color: root.source.available ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
            font: root.source.available ? Tokens.font.label.medium : Tokens.font.label.small
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.source.available
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                // Where a drag or scroll along the foot would land while one is in progress
                readonly property real at: artSeek.preview >= 0 ? artSeek.preview * root.source.length : root.source.position

                text: root.source.length > 0 && root.source.length < 2147483647 ? `${root.timeStr(at)} / ${root.timeStr(root.source.length)}` : root.timeStr(at)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            IconButton {
                icon: "skip_previous"
                type: IconButton.Text
                inactiveOnColour: Colours.palette.m3onSurface
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
                inactiveOnColour: Colours.palette.m3onSurface
                disabled: !root.source.canGoNext
                onClicked: root.source.next()
            }
        }
    }

    // The hairline is too thin to aim at, so the whole strip of card below the controls seeks. It stops
    // where the controls' row begins, so it never takes a press meant for a button
    SeekArea {
        id: artSeek

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Tokens.padding.large - Tokens.spacing.extraSmall
        source: root.source
        progress: root.progress
    }
}
