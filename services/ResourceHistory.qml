pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.services

// Samples CPU, GPU, memory and network usage in the background for the dashboard's
// performance graph, so the graph already has recent history when the dashboard opens.
// Only runs while Graph view is enabled in the dashboard settings.
Singleton {
    id: root

    readonly property bool enabled: GlobalConfig.dashboard.performance.graphView
    readonly property int interval: GlobalConfig.dashboard.resourceUpdateInterval
    readonly property int historySeconds: 120
    readonly property int capacity: Math.ceil(historySeconds * 1000 / interval)

    readonly property var cpu: []
    readonly property var gpu: []
    readonly property var mem: []
    readonly property var net: []

    // Bumped after every sample, since the arrays above are mutated in place
    property int revision

    // Resolves a graph colour setting: a palette role ("primary", "term1", ...) so it follows the
    // colour scheme, or a fixed "#rrggbb" hex. Anything unrecognised falls back to primary.
    function resolveColour(name: string): color {
        if (/^#[0-9a-fA-F]{6}$/.test(name))
            return name;
        const p = Colours.palette;
        const prop = name.startsWith("term") ? name : `m3${name}`;
        return p[prop] ?? p.m3primary;
    }

    function push(arr: var, value: real): void {
        arr.push(isNaN(value) ? 0 : Math.max(0, value));
        if (arr.length > capacity)
            arr.splice(0, arr.length - capacity);
    }

    function sample(): void {
        push(cpu, Cpu.percentage);
        push(gpu, Gpu.percentage);
        push(mem, Memory.percentage);
        push(net, (NetworkUsage.downloadSpeed ?? 0) + (NetworkUsage.uploadSpeed ?? 0));
        revision++;
    }

    function clear(): void {
        for (const arr of [cpu, gpu, mem, net])
            arr.length = 0;
        revision++;
    }

    onEnabledChanged: {
        if (!enabled)
            clear();
    }

    // A different interval changes what each sample means, so start over
    onIntervalChanged: clear()

    ServiceRef {
        service: root.enabled ? Cpu : null
    }

    ServiceRef {
        service: root.enabled ? Gpu : null
    }

    ServiceRef {
        service: root.enabled ? Memory : null
    }

    ServiceRef {
        service: root.enabled ? NetworkUsage : null
    }

    Timer {
        interval: root.interval
        running: root.enabled
        repeat: true
        onTriggered: root.sample()
    }
}
