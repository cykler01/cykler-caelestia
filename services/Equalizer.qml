pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// NOTE(fork): system-wide equalizer. The audio path itself lives in PipeWire (see
// assets/pipewire/caelestia-eq.conf, installed into pipewire.conf.d): a filter-chain virtual sink
// with ten peaking bands, made the default sink so everything is equalized rather than just the
// shell. This singleton only talks to that running node: it finds the node in the graph the shell
// already tracks, writes the band gains into it with pw-cli, points the default output at it while
// the feature is switched on, and keeps the curve across restarts.
//
// The whole feature is opt-in: GlobalConfig.services.equalizer (Settings > Audio) is off by
// default, and while it is off nothing here runs at all - no pw-cli, and no touching of the
// default output. That is deliberate, so that updating the shell cannot change what anybody's
// audio is doing.
Singleton {
    id: root

    // Must match capture.props.node.name and playback.props.node.name in
    // assets/pipewire/caelestia-eq.conf
    readonly property string sinkName: "caelestia_eq.sink"
    readonly property string outputName: "caelestia_eq.out"
    // Centre frequencies of the ten bands, matching the b0..b9 filter nodes in that config
    readonly property var bandFreqs: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property real maxGain: 12

    // Band gains in dB, and the preset they came from ("custom" once a band is moved by hand)
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "flat"

    // The switch in Settings, off by default, and the single switch for the feature: nothing is
    // applied and nothing is routed while it is off (see syncRouting)
    readonly property bool enabled: GlobalConfig.services.equalizer

    // The running sink node, taken from the graph the shell already tracks rather than looked up
    // by hand, and null until PipeWire has loaded the config
    readonly property PwNode node: Pipewire.nodes.values.find(n => n.name === root.sinkName) ?? null
    readonly property bool available: root.node !== null
    // Its id in the graph, which is what the band gains are written to
    readonly property int nodeId: root.node?.id ?? 0

    // Output device to put back when the equalizer is switched off, since being enabled means the
    // filter chain is the default sink (see syncRouting)
    property string previousSink: ""

    // The device being pinned to unity volume once pinUnityTimer fires (see syncRouting) - not a
    // node that needs saving, just a handoff between the two
    property PwNode pinUnityTarget: null

    readonly property var presets: [
        {
            key: "flat",
            label: Tr.tr("Flat"),
            gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
        {
            key: "rock",
            label: Tr.tr("Rock"),
            gains: [4.5, 3.5, 1, -2, -3, -1, 2, 4, 5, 5]
        },
        {
            key: "pop",
            label: Tr.tr("Pop"),
            gains: [-1.5, -0.5, 2, 4, 4.5, 2, 0, -1, -1, -2]
        },
        {
            key: "jazz",
            label: Tr.tr("Jazz"),
            gains: [3, 2, 1, 2, -1, -1, 0, 1.5, 2.5, 3]
        },
        {
            key: "classical",
            label: Tr.tr("Classical"),
            gains: [4, 3, 2, 0, 0, 0, -1, -2, -3, -4]
        },
        {
            key: "electronic",
            label: Tr.tr("Electronic"),
            gains: [5, 4, 2, 0, -2, 0, 2, 4, 4, 3]
        },
        {
            key: "hiphop",
            label: Tr.tr("Hip hop"),
            gains: [6, 5, 2, 1, -2, -2, 0, 2, 3, 3]
        },
        {
            key: "bass",
            label: Tr.tr("Bass boost"),
            gains: [8, 7, 4, 1, 0, 0, 0, 0, 0, 0]
        },
        {
            key: "vocal",
            label: Tr.tr("Vocal"),
            gains: [-2, -3, -1, 2, 4, 4, 3, 1, 0, -1]
        },
        {
            key: "loudness",
            label: Tr.tr("Loudness"),
            gains: [6, 4, 0, -1, -2, -1, 0, 2, 4, 6]
        }
    ]

    // The chain's own two nodes are plumbing rather than output devices: the sink is where audio
    // goes in and the output is where the chain passes it on. Pointing a default at one of those
    // routes everything into something with no hardware behind it, so neither is ever offered or
    // left holding the output
    function isInternalNode(node: PwNode): bool {
        if (!node)
            return false;

        return node.name === root.sinkName || node.name === root.outputName;
    }

    // Used by the panel's power button; the value itself lives in the config so it survives a
    // restart without any state of our own
    function setEnabled(value: bool): void {
        GlobalConfig.services.equalizer = value;
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }

    function setBand(index: int, gain: real): void {
        const next = root.gains.slice();
        next[index] = Math.max(-root.maxGain, Math.min(root.maxGain, gain));
        root.gains = next;
        root.preset = "custom";
        applyTimer.restart();
    }

    function setPreset(key: string): void {
        const preset = root.presets.find(p => p.key === key);
        if (!preset)
            return;

        root.gains = preset.gains.slice();
        root.preset = key;
        applyTimer.restart();
    }

    // An output the equalizer can hand the default back to: a real sink, by name
    function sinkByName(name: string): PwNode {
        if (!name)
            return null;

        return Pipewire.nodes.values.find(node => !node.isStream && node.isSink && node.name === name) ?? null;
    }

    // The chain's playback node, whose output has to be pointed at a real device (see routeOutput)
    readonly property PwNode outputNode: Pipewire.nodes.values.find(n => n.name === root.outputName) ?? null
    // The device the user last picked, while it is plugged in

    readonly property PwNode routeTarget: root.sinkByName(root.previousSink)

    // Sends the chain's output to the device the user picked. PipeWire would otherwise hand it to whichever real
    // output ranks highest, which is not necessarily the one chosen. Only ever writes the target of the chain's own
    // output node (a subject id above zero, since zero is the whole default-devices table)
    function routeOutput(): void {
        if (!root.enabled || !root.available || root.outputNode === null || root.routeTarget === null)
            return;

        const id = root.outputNode.id;
        if (!(id > 0))
            return;

        routeProc.exec(["pw-metadata", `${id}`, "target.object", root.routeTarget.name]);
    }

    // A device was picked while the equalizer is on: the chain stays the default output and its output moves to the
    // device. False when the equalizer is off, so the caller changes the default itself.
    function chooseOutput(node: PwNode): bool {
        if (!root.enabled || !root.available || !node || root.isInternalNode(node))
            return false;

        root.previousSink = node.name;
        if (Pipewire.defaultAudioSink !== root.node)
            Pipewire.preferredDefaultAudioSink = root.node;
        root.routeOutput();
        return true;
    }

    // First real output in the graph, used when the device to restore is gone (unplugged, renamed)
    function firstSink(): PwNode {
        return Pipewire.nodes.values.find(node => !node.isStream && node.isSink && !root.isInternalNode(node)) ?? null;
    }

    // The whole feature hangs off the filter chain being the default output, since audio only
    // passes through it while it is. Switching the equalizer on points the default at it, and
    // switching it off puts a real device back.
    //
    // This goes through the same preference the audio settings page uses, so the two can never
    // fight over the default sink (pactl and the shell each undoing what the other just did is
    // what leaves the output pointing at a sink that is not an output at all). It also only runs
    // when that switch changes, never on a timer, so a device picked in the settings stays picked.
    function syncRouting(adoptCurrent: bool): void {
        if (root.enabled) {
            // The chain can only take the default once it is loaded, and until then there is
            // nothing to route through
            if (!root.available)
                return;

            // The device in use becomes the one to hand the sound to when the switch was just turned on, or when
            // the one picked last is not around. Otherwise the pick from an earlier session stands: after a
            // restart the default is briefly whichever device ranks highest, which says nothing about the choice
            const current = Pipewire.defaultAudioSink;
            if (current !== null && !root.isInternalNode(current) && (adoptCurrent || root.routeTarget === null)) {
                root.previousSink = current.name;
                if (current.audio && root.node.audio) {
                    // The chain's own sink keeps its own volume, separate from the device's -
                    // carrying the device's level onto it here is what keeps the switch from
                    // being audible as a jump
                    root.node.audio.volume = current.audio.volume;
                    root.node.audio.muted = current.audio.muted;
                    // The device's own volume still applies underneath the chain's output (every
                    // sink attenuates whatever plays through it, the chain's playback included),
                    // so leaving it wherever it happened to be stacks a second, invisible
                    // attenuation under the one the slider now shows - pinning it to unity is what
                    // makes the chain's sink the one real volume control from here on. Not done
                    // right here: streams are still playing directly on the device at this point
                    // (the default-sink switch below has not taken effect yet), so pinning it to
                    // unity immediately is briefly audible as a blast at full volume. pinUnityTimer
                    // waits for that switch to actually happen first.
                    root.pinUnityTarget = current;
                    pinUnityTimer.restart();
                }
            }

            Pipewire.preferredDefaultAudioSink = root.node;
            root.routeOutput();
            return;
        }

        // Switched off with nothing of ours holding the output: leave the device that has it
        // alone. Doing even this much when the equalizer was never on is the point - it is what
        // stops a leftover default leaving the machine with no sound at all
        const current = Pipewire.defaultAudioSink;
        if (current !== null && !root.isInternalNode(current))
            return;

        // Ours still has it, so hand it back: the device that was there before if it is still
        // plugged in, otherwise any real output. A default that is simply missing (which is what a
        // sink that no longer exists leaves behind) is only replaced with a device we knew about,
        // so a graph that hasn't picked one yet is left to pick for itself
        const restore = root.sinkByName(root.previousSink) ?? (current !== null ? root.firstSink() : null);
        if (restore) {
            // Same hand-off as switching on, in reverse: carry the level the slider was actually
            // showing back onto the device, instead of leaving it at whatever that device's own
            // volume last happened to be
            if (current && current.audio && restore.audio) {
                restore.audio.volume = current.audio.volume;
                restore.audio.muted = current.audio.muted;
            }
            Pipewire.preferredDefaultAudioSink = restore;
        }
    }

    // Writes every band into the running node in one call, which is what the filter chain wants:
    // pw-cli set-param <node-id> Props '{ params = [ "b0:Gain" 3.0 "b1:Gain" -1.5 ... ] }'
    function apply(): void {
        if (!root.enabled || !root.available)
            return;

        const bands = [];
        for (let i = 0; i < root.bandFreqs.length; i++)
            bands.push(`"b${i}:Gain" ${root.gains[i].toFixed(2)}`);

        applyProc.exec(["pw-cli", "set-param", `${root.nodeId}`, "Props", `{ params = [ ${bands.join(" ")} ] }`]);
    }

    onEnabledChanged: {
        root.syncRouting(true);
        if (root.enabled)
            applyTimer.restart();
    }

    // The chain appearing is the point at which audio can start going through it; a chain that has
    // gone away cannot be the default output, so whatever it was holding has to come back
    onAvailableChanged: {
        root.syncRouting(false);
        if (root.enabled && root.available)
            applyTimer.restart();
    }

    // Node lookups come up empty until the shell has finished its first sync with PipeWire, in
    // which case this does nothing and the connection below settles the routing instead
    Component.onCompleted: root.syncRouting(false)

    onPreviousSinkChanged: saveTimer.restart()

    onOutputNodeChanged: root.routeOutput()
    onRouteTargetChanged: root.routeOutput()

    onGainsChanged: saveTimer.restart()
    onPresetChanged: saveTimer.restart()

    // Once the graph and the metadata the default output lives in are known, the routing is
    // settled for real - which is what gives back an output a previous session left pointing at
    // the filter chain
    Connections {
        function onReadyChanged(): void {
            root.syncRouting(false);
        }

        target: Pipewire
    }

    FileView {
        id: state

        printErrors: false
        path: `${Paths.state}/equalizer.json`
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (Array.isArray(data.gains) && data.gains.length === root.bandFreqs.length)
                    root.gains = data.gains.map(g => Number(g) || 0);
                if (typeof data.preset === "string")
                    root.preset = data.preset;
                if (typeof data.previousSink === "string")
                    root.previousSink = data.previousSink;

                // The device to hand the output back to is only known now, so a restore that
                // happened before this loaded can be corrected
                root.syncRouting(false);
            } catch (e) {
                // Nothing saved yet, or unreadable: the defaults stand
            }
        }
    }

    Process {
        id: applyProc
    }

    Process {
        id: routeProc
    }

    // Dragging a band fires a lot of small changes; one call per settle is plenty
    Timer {
        id: applyTimer

        interval: 80
        onTriggered: root.apply()
    }

    // Gives the default-sink switch time to actually move playback onto the chain before the
    // device it was just taken off is pinned to unity (see syncRouting) - pinning it in the same
    // tick as the switch means it briefly plays whatever was already running at full volume
    Timer {
        id: pinUnityTimer

        interval: 300
        onTriggered: {
            if (root.pinUnityTarget && root.pinUnityTarget.audio) {
                root.pinUnityTarget.audio.volume = 1;
                root.pinUnityTarget.audio.muted = false;
            }
            root.pinUnityTarget = null;
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: state.setText(JSON.stringify({
            gains: root.gains,
            preset: root.preset,
            previousSink: root.previousSink
        }))
    }
}
