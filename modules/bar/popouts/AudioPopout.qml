pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts

    implicitWidth: Tokens.sizes.bar.audioWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.trCtx("Output device", "audio output device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sinks

            RowLayout {
                id: control

                required property PwNode modelData
                readonly property bool isOutput: Audio.outputDevice?.id === control.modelData.id

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledRadioButton {
                    Layout.fillWidth: true
                    ButtonGroup.group: sinks
                    checked: control.isOutput
                    onClicked: Audio.setAudioSink(control.modelData)
                    text: control.modelData.description
                }

                // Also play here, alongside the output rather than instead of it: the device gets a
                // loopback of whatever the output is playing (see services/AudioMirror.qml). Not
                // offered on the output itself, which is already carrying the sound
                IconButton {
                    icon: "speaker_group"
                    type: IconButton.Tonal
                    isRound: true
                    isToggle: true
                    font: Tokens.font.icon.small
                    visible: !control.isOutput
                    checked: AudioMirror.isMirrored(control.modelData)
                    onClicked: AudioMirror.toggle(control.modelData)
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.trCtx("Input device", "audio input device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sources

            StyledRadioButton {
                required property PwNode modelData

                Layout.fillWidth: true
                ButtonGroup.group: sources
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setAudioSource(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Audio.muted ? Tr.tr("Volume (muted)") : Tr.tr("Volume (%1%)").arg(Math.round(Audio.volume * 100))
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: value => Audio.setVolume(value)
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}
