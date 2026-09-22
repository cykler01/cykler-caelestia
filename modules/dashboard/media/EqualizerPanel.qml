pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the media tab's equalizer drawer, the second thing that can live under the player
// next to the library. The bands are PipeWire's, applied live through the Equalizer service (see
// assets/pipewire/caelestia-eq.conf for the audio side of it).
StyledClippingRect {
    id: root

    readonly property bool available: Equalizer.available

    // "62", "1k", "16k"
    function freqLabel(freq: real): string {
        return freq >= 1000 ? `${freq / 1000}k` : `${freq}`;
    }

    function gainLabel(gain: real): string {
        const rounded = Math.abs(gain) < 0.05 ? 0 : gain;
        return `${rounded > 0 ? "+" : ""}${rounded.toFixed(1)}`;
    }

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
                text: "graphic_eq"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Equalizer")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            SplitButton {
                menuOnTop: true
                menuItems: presetItems.instances
                active: presetItems.instances.find(i => i.modelData.key === Equalizer.preset) ?? null
                menu.onItemSelected: item => Equalizer.setPreset((item as PresetItem).modelData.key)
                fallbackIcon: "tune"
                fallbackText: Tr.tr("Preset")
                disabled: !root.available
            }

            // Turning this off hands the output device back, so it doubles as the "stop
            // routing my audio through the filter chain" switch. The same option lives in
            // Settings > Audio, which is what has to be on before this panel is even reachable
            IconButton {
                icon: "equalizer"
                type: Equalizer.enabled ? IconButton.Filled : IconButton.Tonal
                isToggle: true
                checked: Equalizer.enabled
                onClicked: Equalizer.toggle()
            }
        }

        StyledText {
            id: hint

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.small
            visible: !root.available
            text: Tr.tr("The PipeWire equalizer isn't loaded — install assets/pipewire/caelestia-eq.conf and restart PipeWire")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        RowLayout {
            id: bands

            anchors.top: root.available ? header.bottom : hint.bottom
            anchors.topMargin: root.available ? Tokens.spacing.small : Tokens.spacing.medium
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: Equalizer.bandFreqs

                ColumnLayout {
                    id: band

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.gainLabel(Equalizer.gains[band.index])
                        color: Equalizer.gains[band.index] === 0 ? Colours.palette.m3outline : Colours.palette.m3primary
                        font: Tokens.font.label.small
                        animate: true
                    }

                    EqualizerBand {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: root.freqLabel(band.modelData)
                        gain: Equalizer.gains[band.index]
                        maxGain: Equalizer.maxGain
                        enabled: root.available
                        onMoved: gain => Equalizer.setBand(band.index, gain)
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.freqLabel(band.modelData)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

    Variants {
        id: presetItems

        model: Equalizer.presets

        PresetItem {}
    }

    component PresetItem: MenuItem {
        required property var modelData

        text: modelData.label
        icon: "tune"
    }
}
