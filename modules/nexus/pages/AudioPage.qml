pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Audio")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Output
        SliderRow {
            first: true
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            // SEARCH: speaker headphones sink playback device
            label: Tr.trCtx("Output", "audio output")
            valueLabel: Strings.percentOne(value)
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio output muted")
            checked: Audio.silent
            onToggled: {
                if (checked !== Audio.silent)
                    Audio.toggleMuted();
            }
        }

        AudioDeviceList {
            nodes: Audio.sinks
            currentId: Audio.outputDevice?.id ?? -1
            iconName: "speaker"
            placeholderIcon: "speaker"
            placeholderText: Tr.trCtx("No output devices", "no audio outputs")
            onSelected: node => Audio.setAudioSink(node)
        }

        // Playing on more than one device at once. Each one switched on here gets a loopback of the
        // output rather than taking it over, so the device above stays the output (see
        // services/AudioMirror.qml)
        SectionHeader {
            // SEARCH: multiple outputs both speakers headphones at once mirror simultaneous
            text: Tr.tr("Play on several devices")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("Anything playing on the output above is also sent to these, in step with it. They keep their own volume.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        InfoRow {
            first: true
            last: true
            visible: AudioMirror.available.length === 0
            icon: "speaker"
            label: Tr.tr("No other output devices")
            subtext: Tr.tr("Plug in or connect another one and it shows up here")
        }

        Repeater {
            model: AudioMirror.available

            ToggleRow {
                required property PwNode modelData
                required property int index

                first: index === 0
                last: index === AudioMirror.available.length - 1
                text: modelData.description || modelData.name
                subtext: AudioMirror.isMirrored(modelData) ? Tr.tr("Also playing") : Tr.tr("Silent")
                checked: AudioMirror.isMirrored(modelData)
                onToggled: AudioMirror.setMirrored(modelData, checked)
            }
        }

        // A device that was switched on and has since gone away keeps its place in the list, so say
        // where it went rather than leaving the count looking wrong
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            visible: AudioMirror.waitingCount > 0
            text: Tr.trN("%n device is switched on but not connected — it picks up again when it comes back", "%n devices are switched on but not connected — they pick up again when they come back", AudioMirror.waitingCount)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // Input
        SliderRow {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            // SEARCH: microphone mic source recording device
            label: Tr.trCtx("Input", "audio input")
            valueLabel: Strings.percentOne(value)
            value: Audio.sourceVolume
            enabled: !Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio input muted")
            checked: Audio.sourceMuted
            onToggled: Audio.setStreamMuted(Audio.source, checked)
        }

        AudioDeviceList {
            nodes: Audio.sources
            currentId: Audio.source?.id ?? -1
            iconName: "mic"
            placeholderIcon: "mic_off"
            placeholderText: Tr.trCtx("No input devices", "no audio inputs")
            onSelected: node => Audio.setAudioSource(node)
        }

        // Per-app volumes
        NavRow {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            last: true

            icon: "tune"
            text: Tr.tr("App volumes")
            subtext: Audio.streams.length === 0 ? Tr.tr("No apps playing audio") : Tr.trN("%n app playing audio", "%n apps playing audio", Audio.streams.length)
            onClicked: root.nState.openSubPage(1)
        }

        // Sound effects
        SectionHeader {
            text: Tr.tr("Sound effects")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable sound effects")
            subtext: Tr.tr("Play short sounds for things like screen lock, low battery and screenshots")
            checked: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.enabled = checked
        }

        SliderRow {
            icon: "volume_up"
            label: Tr.tr("SFX volume")
            valueLabel: Strings.percentOne(value)
            value: GlobalConfig.services.soundEffects.sfxVolume
            enabled: GlobalConfig.services.soundEffects.enabled
            onMoved: v => GlobalConfig.services.soundEffects.sfxVolume = v
        }

        SliderRow {
            icon: "notifications"
            label: Tr.tr("Notification volume")
            valueLabel: Strings.percentOne(value)
            value: GlobalConfig.services.soundEffects.notificationVolume
            enabled: GlobalConfig.services.soundEffects.enabled
            onMoved: v => GlobalConfig.services.soundEffects.notificationVolume = v
        }

        ToggleRow {
            text: Tr.tr("Camera click")
            checked: GlobalConfig.services.soundEffects.cameraClick
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.cameraClick = checked
        }

        ToggleRow {
            text: Tr.tr("Charging started")
            checked: GlobalConfig.services.soundEffects.chargingStarted
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.chargingStarted = checked
        }

        ToggleRow {
            text: Tr.tr("Volume tick")
            checked: GlobalConfig.services.soundEffects.volumeTick
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.volumeTick = checked
        }

        ToggleRow {
            text: Tr.tr("Screen lock")
            checked: GlobalConfig.services.soundEffects.screenLock
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.screenLock = checked
        }

        ToggleRow {
            text: Tr.tr("Screen unlock")
            checked: GlobalConfig.services.soundEffects.screenUnlock
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.screenUnlock = checked
        }

        ToggleRow {
            text: Tr.tr("Low battery")
            checked: GlobalConfig.services.soundEffects.lowBattery
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.lowBattery = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Screen record")
            checked: GlobalConfig.services.soundEffects.screenRecord
            enabled: GlobalConfig.services.soundEffects.enabled
            onToggled: GlobalConfig.services.soundEffects.screenRecord = checked
        }

        // Equalizer
        SectionHeader {
            text: Tr.tr("Equalizer")
        }

        // Off by default on purpose: it routes all audio through a PipeWire filter chain, which
        // is not something an update should do to somebody's sound without being asked
        ToggleRow {
            first: true
            last: true
            // SEARCH: eq equaliser bass treble
            text: Tr.tr("System-wide equalizer")
            subtext: Tr.tr("Filter everything playing through a ten band equalizer, tuned in the media tab")
            checked: GlobalConfig.services.equalizer
            onToggled: GlobalConfig.services.equalizer = checked
        }

        // Switching it on before the filter chain is loaded does nothing audible, so say so here
        // rather than leaving a switch that looks broken
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            visible: GlobalConfig.services.equalizer && !Equalizer.available
            text: Tr.tr("PipeWire hasn't loaded the filter chain yet — copy assets/pipewire/caelestia-eq.conf to ~/.config/pipewire/pipewire.conf.d and restart PipeWire.")
            color: Colours.palette.m3error
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }
}
