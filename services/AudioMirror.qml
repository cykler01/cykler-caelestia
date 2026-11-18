pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services
import qs.utils

// NOTE(fork): playing out of more than one device at once - speakers and a headset, a desk and a
// kitchen speaker - without giving up the device the output is actually set to.
//
// There is no combined device here and nothing is loaded into the audio daemon: each extra device
// gets a loopback of its own, capturing the monitor of whatever apps are playing into and handing
// it to that device. Which means:
//
//   - the output stays the output. Per-app routing, its volume and the picker all go on working on
//     the device they always did, and every extra one is a mirror of it rather than a slave of a
//     virtual sink that has taken the output's place
//   - the equalizer is upstream. While it is on, the default sink is its filter chain, so a mirror
//     carries the equalized sound rather than slipping past it
//   - nothing of ours outlives the shell. A loaded module would stay loaded after a crash, with
//     audio quietly going somewhere nobody asked for; these are processes we own, and each one is
//     wrapped in a watch on its own stdin so it goes when the shell does, however the shell goes
//
// Devices are remembered by name, so one that comes back (a dock, a speaker that was asleep) is
// picked up again on its own.
Singleton {
    id: root

    // The devices asked for, by node name, whether or not they are plugged in right now
    property var targets: []

    // What apps actually play into: the default sink, which is the equalizer's chain while that is
    // switched on
    readonly property PwNode primary: Audio.sink
    readonly property string primaryName: root.primary?.name ?? ""
    // The device the sound already ends up on. While the equalizer is on this is not the default
    // sink but the device its chain hands off to, and mirroring onto it would play it twice
    readonly property string deviceName: Audio.outputDevice?.name ?? ""

    // The devices that can be added: every output except the one already carrying the sound
    readonly property var available: Audio.sinks.filter(n => n.name !== root.deviceName && n.name !== root.primaryName)

    // "<source>\u0001<target>" per running mirror. The source is in the key rather than read inside
    // the delegate so that changing the output tears the loopbacks down and brings them back up
    // against the new one, which a changed command on a running process would not do
    readonly property var mirrors: {
        if (root.primaryName === "")
            return [];

        const out = [];
        for (const node of Audio.sinks) {
            if (node.name === root.primaryName || node.name === root.deviceName)
                continue;

            if (root.targets.includes(node.name))
                out.push(`${root.primaryName}\u0001${node.name}`);
        }
        return out;
    }
    readonly property int count: root.mirrors.length
    // A device that was asked for and is not there, so the settings can say so rather than leaving
    // a switch on with nothing behind it
    readonly property int waitingCount: root.targets.filter(name => name !== root.deviceName && name !== root.primaryName && !Audio.sinks.some(n => n.name === name)).length

    function isMirrored(node: PwNode): bool {
        return !!node && root.targets.includes(node.name);
    }

    function setMirrored(node: PwNode, on: bool): void {
        if (!node?.name)
            return;

        const has = root.targets.includes(node.name);
        if (on === has)
            return;

        root.targets = on ? [...root.targets, node.name] : root.targets.filter(n => n !== node.name);
        saveTimer.restart();
    }

    function toggle(node: PwNode): void {
        root.setMirrored(node, !root.isMirrored(node));
    }

    function clear(): void {
        if (root.targets.length === 0)
            return;

        root.targets = [];
        saveTimer.restart();
    }

    // One loopback per mirror, each its own process
    Instantiator {
        model: root.mirrors

        Process {
            id: loopback

            required property string modelData
            readonly property var pair: loopback.modelData.split("\u0001")

            // The wrapper is what ties the loopback's life to the shell's: it reads the stdin pipe
            // the shell holds open and kills the loopback the moment that pipe closes, which is
            // what happens when the shell exits - including the ways it never gets to run any
            // teardown of its own. The trap covers the ordinary case, a Process stopped from here
            command: ["sh", "-c", "pw-loopback \"$@\" & p=$!; trap 'kill $p 2>/dev/null' EXIT TERM INT; cat >/dev/null 2>&1; kill $p 2>/dev/null", "sh", "-n", "caelestia-mirror", "-i", `stream.capture.sink=true target.object="${loopback.pair[0]}" node.description="Caelestia mirror"`, "-o", `target.object="${loopback.pair[1]}" node.description="Caelestia mirror"`]
            stdinEnabled: true
            running: true

            Component.onDestruction: loopback.running = false
        }
    }

    FileView {
        id: state

        printErrors: false
        path: `${Paths.state}/audio-mirror.json`
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (Array.isArray(data.targets))
                    root.targets = data.targets.filter(n => typeof n === "string");
            } catch (e) {
                // Nothing saved yet, or unreadable: nothing is mirrored
            }
        }
    }

    // Flicking a few switches in a row is one write, not one per switch
    Timer {
        id: saveTimer

        interval: 500
        onTriggered: state.setText(JSON.stringify({
            targets: root.targets
        }))
    }
}
