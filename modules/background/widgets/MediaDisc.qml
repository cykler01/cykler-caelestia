pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// The media card's disc: the cover pressed into a record that turns while the track plays. The record's
// label is the play button, and the position runs round the rim, so the disc is the whole player and
// only the name has to sit outside it
Item {
    id: root

    required property MediaSource source
    required property real progress

    implicitWidth: 180
    implicitHeight: 180

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        Item {
            id: stage

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real size: Math.min(width, height)

            // The position, as a ring just outside the record
            CircularProgress {
                anchors.centerIn: parent
                width: stage.size
                height: stage.size
                visible: root.source.available
                value: root.progress
                strokeWidth: 3
                spacing: Tokens.spacing.small
                fgColour: Colours.palette.m3primary
                bgColour: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }

            Item {
                id: record

                anchors.centerIn: parent
                width: stage.size - 16
                height: width

                // One turn every 12 s, stepped at the shared decorative rate the way the dashboard's cover
                // turns (components/widgets/CoverArt.qml). A pause leaves the record where it stopped
                // rather than snapping it back, so playing again carries on from there
                Timer {
                    property real last

                    interval: PowerSaving.frameMs
                    repeat: true
                    running: root.source.isPlaying && PowerSaving.animations && !PowerSaving.onBattery && root.visible
                    onRunningChanged: last = Date.now()
                    onTriggered: {
                        const now = Date.now();
                        spinner.rotation = (spinner.rotation + (now - last) / 12000 * 360) % 360;
                        last = now;
                    }
                }

                Item {
                    id: spinner

                    anchors.fill: parent

                    ClipRect {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHigh

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            source: root.source.available ? root.source.coverSource : ""
                        }
                    }

                    // Grooves: faint rings over the art, which are what make it read as a record rather
                    // than a round picture, and what let the eye see it turn
                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            anchors.centerIn: parent
                            width: spinner.width * (0.92 - index * 0.13)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Colours.palette.m3surface, 0.28)
                        }
                    }

                    // A sheen from one side, so the turning shows even on flat, single-colour art
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
                            }
                            GradientStop {
                                position: 0.5
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Colours.palette.m3shadow, 0.18)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
                }

                // The label: a ring of the card's own surface, as if the middle were punched through, with
                // the play button set into it. It stays still while the record turns under it
                StyledRect {
                    anchors.centerIn: parent
                    width: Math.round(record.width * 0.38)
                    height: width
                    radius: width / 2
                    color: Colours.palette.m3surface
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

                    StyledRect {
                        id: label

                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.small * 2
                        height: width
                        radius: width / 2
                        color: root.source.available ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: !root.source.available ? "album" : root.source.isPlaying ? "pause" : "play_arrow"
                            color: root.source.available ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                            fill: 1
                            fontStyle: Tokens.font.icon.large
                        }

                        StateLayer {
                            radius: width / 2
                            color: Colours.palette.m3onPrimary
                            disabled: !root.source.available || !root.source.canTogglePlaying
                            onClicked: root.source.togglePlaying()
                        }
                    }
                }
            }

            // Skipping sits either side of the record, level with the label
            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.source.available
                icon: "skip_previous"
                type: IconButton.Text
                disabled: !root.source.canGoPrevious
                onClicked: root.source.previous()
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.source.available
                icon: "skip_next"
                type: IconButton.Text
                disabled: !root.source.canGoNext
                onClicked: root.source.next()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.source.available ? (root.source.title || Tr.tr("Unknown title")) : Tr.tr("Nothing playing")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.source.available ? (root.source.artist || Tr.tr("Unknown artist")) : Tr.tr("Play something in any app")
                color: root.source.available ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                font: root.source.available ? Tokens.font.label.medium : Tokens.font.label.small
            }
        }
    }
}
