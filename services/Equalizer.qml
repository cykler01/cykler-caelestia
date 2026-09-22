pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// NOTE(fork): system-wide equalizer. The audio path itself lives in PipeWire (see
// assets/pipewire/caelestia-eq.conf, installed into pipewire.conf.d): a filter-chain virtual sink
// with ten peaking bands, made the default sink so everything is equalized rather than just the
// shell. This singleton only talks to that running node, writing the band gains into it with
// pw-cli, and keeps the curve across restarts.
//
// The whole feature is opt-in: GlobalConfig.services.equalizer (Settings > Audio) is off by
// default, and while it is off nothing here runs at all - no pw-cli, no pactl, no routing. That is
// deliberate, so that updating the shell cannot change what anybody's audio is doing.
Singleton {
    id: root

    // Must match capture.props.node.name in assets/pipewire/caelestia-eq.conf
    readonly property string sinkName: "caelestia_eq.sink"
    // Centre frequencies of the ten bands, matching the b0..b9 filter nodes in that config
    readonly property var bandFreqs: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property real maxGain: 12

    // Band gains in dB, and the preset they came from ("custom" once a band is moved by hand)
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "flat"

    // The switch in Settings, off by default, and the single switch for the feature: nothing is
    // applied and nothing is routed while it is off (see syncRouting)
    readonly property bool enabled: GlobalConfig.services.equalizer

    // Id of the PipeWire node, 0 while the config hasn't been installed and loaded. It is only
    // ever looked up while the equalizer is switched on
    property int nodeId: 0
    readonly property bool available: root.nodeId > 0
    // Output device to put back when the equalizer is switched off, since being enabled means the
    // filter chain is the default sink (see syncRouting)
    property string previousSink: ""

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

    // Everything only passes through the filter chain while it is the default sink, so switching
    // the equalizer on points the default at it; switching it off puts the device back. There is
    // nothing to route while the option is off and no device was ever taken, which is the state
    // every install starts in
    function syncRouting(): void {
        if (root.enabled) {
            if (root.available)
                defaultSinkProc.running = true;
            return;
        }

        if (root.previousSink.length > 0)
            setSinkProc.exec(["pactl", "set-default-sink", root.previousSink]);
    }

    // Writes every band into the running node in one call, which is what the filter chain wants:
    // pw-cli set-param <node-id> Props '{ params = [ "b0:Gain" 3.0 "b1:Gain" -1.5 ... ] }'
    function apply(): void {
        if (!root.enabled)
            return;

        if (root.nodeId <= 0) {
            findProc.running = true;
            return;
        }

        const bands = [];
        for (let i = 0; i < root.bandFreqs.length; i++)
            bands.push(`"b${i}:Gain" ${root.gains[i].toFixed(2)}`);

        applyProc.exec(["pw-cli", "set-param", `${root.nodeId}`, "Props", `{ params = [ ${bands.join(" ")} ] }`]);
    }

    onEnabledChanged: {
        applyTimer.restart();
        root.syncRouting();
    }

    onAvailableChanged: {
        if (root.available)
            root.syncRouting();
    }

    onPreviousSinkChanged: saveTimer.restart()

    onGainsChanged: saveTimer.restart()
    onPresetChanged: saveTimer.restart()

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
            } catch (e) {
                // Nothing saved yet, or unreadable: the defaults stand
            }
        }
    }

    Process {
        id: findProc

        command: ["pw-cli", "ls", "Node"]
        stdout: StdioCollector {
            onStreamFinished: {
                // pw-cli prints "id <n>, type ..." and then that node's properties, so walk the
                // lines remembering the last id and match the sink name against it
                let id = 0;
                const lines = text.split("\n");
                for (const line of lines) {
                    const node = line.match(/id (\d+), type/);
                    if (node) {
                        id = parseInt(node[1]);
                        continue;
                    }

                    const name = line.match(/node\.name = "(.*)"/);
                    if (!name || name[1] !== root.sinkName)
                        continue;

                    const appeared = id !== root.nodeId;
                    root.nodeId = id;
                    if (appeared)
                        root.apply();
                    return;
                }

                root.nodeId = 0;
            }
        }
    }

    Process {
        id: applyProc

        onExited: code => { // qmllint disable signal-handler-parameters
            // The node disappears if the audio daemon restarts, so look it up again
            if (code !== 0) {
                root.nodeId = 0;
                findProc.running = true;
            }
        }
    }

    Process {
        id: defaultSinkProc

        command: ["pactl", "get-default-sink"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sink = text.trim();
                if (!sink)
                    return;

                // Already routed through the filter chain, so there is nothing to switch and no
                // device remembered yet: adopt what is there and find a real one to fall back to
                if (sink === root.sinkName) {
                    if (root.previousSink.length === 0)
                        listSinksProc.running = true;
                    return;
                }

                root.previousSink = sink;
                if (root.enabled)
                    setSinkProc.exec(["pactl", "set-default-sink", root.sinkName]);
            }
        }
    }

    Process {
        id: setSinkProc
    }

    Process {
        id: listSinksProc

        command: ["pactl", "list", "short", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                // First output that isn't our own filter chain, used when the equalizer is
                // switched off without one having been recorded
                const lines = text.trim().split("\n");
                for (const line of lines) {
                    const name = line.split("\t")[1];
                    if (!name || name === root.sinkName)
                        continue;

                    root.previousSink = name;
                    setSinkProc.exec(["pactl", "set-default-sink", name]);
                    return;
                }
            }
        }
    }

    // Dragging a band fires a lot of small changes; one call per settle is plenty
    Timer {
        id: applyTimer

        interval: 80
        onTriggered: root.apply()
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

    // The node only exists once the config is installed and the daemon restarted, so keep looking
    // while it is missing and let the panel tell the user what to do. Nothing is polled while the
    // equalizer is switched off, which is the default
    Timer {
        running: root.enabled && root.nodeId <= 0
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: findProc.running = true
    }
}
