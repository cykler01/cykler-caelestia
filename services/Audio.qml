pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property string previousSinkName: ""
    // The output the user picked last, and whether it has been put back yet this start
    property string lastOutput
    property bool outputStateLoaded
    property bool outputRestored
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    // The output device actually in use. While the equalizer is on the default sink is its filter chain, which is
    // not offered as a device, so this is the real one the chain hands the sound on to
    readonly property PwNode outputDevice: Equalizer.isInternalNode(sink) ? Equalizer.sinkByName(Equalizer.previousSink) : sink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    // A tap on the OSD popping it out even when the value doesn't actually move
    signal volumeLimitReached()

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function toggleMuted(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // Keybind/scroll-wheel steps, as opposed to setVolume above: these shouldn't un-mute, since
    // stepping volume while muted is "change the level for when I unmute", not "unmute me now"
    function adjustVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
    }

    function incrementVolume(amount: real): void {
        if (root.volume >= GlobalConfig.services.maxVolume) {
            root.volumeLimitReached();
            SoundEffects.play("volumeTick");
            return;
        }

        adjustVolume(volume + (amount || GlobalConfig.services.audioIncrement));
        SoundEffects.play("volumeTick");
    }

    function decrementVolume(amount: real): void {
        if (root.volume <= 0) {
            root.volumeLimitReached();
            SoundEffects.play("volumeTick");
            return;
        }

        adjustVolume(volume - (amount || GlobalConfig.services.audioIncrement));
        SoundEffects.play("volumeTick");
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    // Makes a device the output: through the equalizer when it is on, otherwise as the default sink itself
    function applyOutput(node: PwNode): void {
        if (Equalizer.chooseOutput(node))
            return;

        Pipewire.preferredDefaultAudioSink = node;
    }

    // What the user picks is remembered, so it is still the output after the shell restarts
    function setAudioSink(newSink: PwNode): void {
        if (!newSink)
            return;

        if (newSink.name !== lastOutput) {
            lastOutput = newSink.name;
            outputSaveTimer.restart();
        }

        // The device already in use: nothing more to change. This matters while the equalizer is on, because the
        // radio buttons in the bar popout report a click on the device they show as selected as soon as it is set,
        // and acting on that would take the default output back from the equalizer
        if (newSink === outputDevice)
            return;

        applyOutput(newSink);
    }

    // Puts the output the user last picked back once the device is there (and the equalizer, if it is on, is ready).
    // Only once per start, so a device chosen afterwards by other means is not overridden
    function restoreOutput(): void {
        if (outputRestored || !outputStateLoaded)
            return;

        const node = sinks.find(s => s.name === lastOutput);
        if (!node || (Equalizer.enabled && !Equalizer.available))
            return;

        outputRestored = true;
        if (node !== outputDevice)
            applyOutput(node);
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;

        const currentIndex = sinks.findIndex(s => s === outputDevice);
        const nextIndex = (currentIndex + 1) % sinks.length;
        setAudioSink(sinks[nextIndex]);
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return Tr.trCtx("Unknown", "unknown audio stream");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || Tr.trCtx("Unknown application", "unknown application audio stream");
    }

    function refreshNodes(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];

        for (const node of Pipewire.nodes.values) {
            if (!node.isStream) {
                if (node.isSink) {
                    // The equalizer's virtual sink is not an output device: offering it would
                    // route audio into something with no hardware behind it, and the shell
                    // remembers the pick, so it would stay routed there
                    if (Equalizer.isInternalNode(node))
                        continue;

                    newSinks.push(node);
                } else if (node.audio) {
                    newSources.push(node);
                }
            } else if (node.audio) {
                newStreams.push(node);
            }
        }

        root.sinks = newSinks;
        root.sources = newSources;
        root.streams = newStreams;
    }

    onSinksChanged: restoreOutput()

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || Tr.trCtx("Unknown device", "unknown audio device");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.utilities.toasts.audioOutputChanged)
            Toaster.toast(Tr.tr("Audio output changed"), Tr.tr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || Tr.trCtx("Unknown device", "unknown audio device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.utilities.toasts.audioInputChanged)
            Toaster.toast(Tr.tr("Audio input changed"), Tr.tr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    // Populate immediately: Pipewire.nodes may already be filled by the time this
    // lazily-loaded singleton is created, so onValuesChanged would never fire.
    Component.onCompleted: {
        refreshNodes();
        previousSinkName = sink?.description || sink?.name || Tr.trCtx("Unknown device", "unknown audio device");
        previousSourceName = source?.description || source?.name || Tr.trCtx("Unknown device", "unknown audio device");
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshNodes();
        }

        target: Pipewire.nodes
    }

    Connections {
        function onAvailableChanged(): void {
            root.restoreOutput();
        }

        target: Equalizer
    }

    FileView {
        id: outputState

        path: `${Paths.state}/audio-output.json`
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (typeof data.output === "string")
                    root.lastOutput = data.output;
            } catch (e) {
                // Nothing saved yet, or unreadable: nothing to put back
            }
            root.outputStateLoaded = true;
            root.restoreOutput();
        }
        onLoadFailed: root.outputStateLoaded = true
    }

    Timer {
        id: outputSaveTimer

        interval: 500
        onTriggered: outputState.setText(JSON.stringify({
            output: root.lastOutput
        }))
    }

    // Always track the current defaults so volume/mute bind even if the lists
    // momentarily lag behind the default node.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams].filter(n => n)
    }

    CavaProvider {
        id: cava

        bars: GlobalConfig.services.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        function volumeUp(): void {
            root.incrementVolume(0);
        }

        function volumeDown(): void {
            root.decrementVolume(0);
        }

        function toggleMute(): void {
            root.toggleMuted();
        }

        target: "audio"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "volumeUp"
        description: "Raise volume"
        onPressed: root.incrementVolume(0)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "volumeDown"
        description: "Lower volume"
        onPressed: root.decrementVolume(0)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "volumeMute"
        description: "Toggle mute"
        onPressed: root.toggleMuted()
    }
}
