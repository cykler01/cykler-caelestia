pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): the media tab's per-app volume drawer, the sibling of the equalizer one: the same
// panel under the player, but listing the streams that are playing right now with a slider for
// each one's own volume. The list is the audio service's streams, so whatever PipeWire reports -
// a browser, a game, the in-shell player - turns up here, and the level set on a row stays with
// that app rather than with the output device.
ClipRect {
    id: root

    clip: true
    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        visible: root.enabled && height > 0

        RowLayout {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: "tune"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("App volumes")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                visible: Audio.streams.length > 0
                text: Tr.trN("%n app", "%n apps", Audio.streams.length)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        StyledText {
            id: empty

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.medium
            visible: Audio.streams.length === 0
            text: Tr.tr("No apps playing audio")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        StyledListView {
            id: streams

            anchors.top: header.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: Audio.streams.length > 0
            clip: true
            spacing: Tokens.spacing.extraSmall
            model: Audio.streams

            delegate: ColumnLayout {
                id: stream

                required property PwNode modelData

                width: streams.width
                height: implicitHeight
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: Icons.getVolumeIcon(stream.modelData?.audio?.volume ?? 0, stream.modelData?.audio?.muted ?? false)
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Audio.getStreamName(stream.modelData)
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: Strings.percentOne(stream.modelData?.audio?.volume ?? 0)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }

                CustomMouseArea {
                    function onWheel(event: WheelEvent): void {
                        const step = GlobalConfig.services.audioIncrement;
                        const volume = Audio.getStreamVolume(stream.modelData);
                        Audio.setStreamVolume(stream.modelData, volume + (event.angleDelta.y > 0 ? step : -step));
                    }

                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.medium * 2

                    StyledSlider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: parent.implicitHeight
                        radius: Tokens.rounding.small
                        value: stream.modelData?.audio?.volume ?? 0
                        onInteraction: v => Audio.setStreamVolume(stream.modelData, v)
                    }
                }
            }
        }
    }
}
