pragma Singleton

import QtQuick
import Quickshell
import qs.services

// NOTE(fork): the stopwatch behind the timer panel's second tab. It counts up rather than down and
// keeps laps, which is the one thing the countdown cannot be made to do.
//
// It lives in a service for the same reason CountdownTimer does: the panel it is started from is
// torn down the moment the sidebar closes, and a stopwatch that stopped when you looked away would
// be no use at all.
//
// Everything is read off the wall clock rather than counted in beats, so the reading stays right
// across a shell that was busy, a machine that slept, and a tick that arrived late.
Singleton {
    id: root

    // Milliseconds banked from previous runs, and when the current run started (Date.now())
    property real accumulated: 0
    property real startedAt: 0
    property bool running: false

    // Milliseconds on the clock right now. Refreshed by the ticker below while it runs, and set
    // exactly whenever it is started, paused or reset
    property real elapsed: 0

    // Running, or stopped part way through and not yet cleared
    readonly property bool active: root.running || root.elapsed > 0

    // The laps taken, newest first: { index, at, split }. `at` is the reading when it was taken and
    // `split` how long that lap itself ran for
    property var laps: []

    // More than anyone is going to read back, and a bound on what a stuck finger can make
    readonly property int maxLaps: 99

    readonly property string display: root.format(root.elapsed)
    // The same reading without the hundredths, for the notch's side bubble, where a circle the
    // size of the clock has no room for digits moving that fast
    readonly property string shortDisplay: root.formatShort(root.wholeSeconds * 1000)
    // How far through the current minute it is: the one thing a count with no end can fill a ring
    // with, which reads as a second hand going round
    readonly property real minuteProgress: (root.wholeSeconds % 60) / 60

    // Both of the above are read by the notch's side bubble, which is on screen for as long as the
    // stopwatch runs. Taken off the whole second rather than off `elapsed`, they change once a
    // second instead of on every tick, so the ring is redrawn once a second rather than thirty
    // times - the hundredths are for the panel, where someone is actually looking at them
    readonly property int wholeSeconds: Math.floor(root.elapsed / 1000)
    // What the current, unfinished lap has run for
    readonly property real currentSplit: root.elapsed - (root.laps.length > 0 ? root.laps[0].at : 0)

    // Which laps were the quickest and the slowest of the ones taken, so the panel can pick them
    // out. Nothing at all until there are two to compare, since the fastest of one lap says nothing
    readonly property int fastestLap: root.extremeLap(true)
    readonly property int slowestLap: root.extremeLap(false)

    function extremeLap(fastest: bool): int {
        if (root.laps.length < 2)
            return -1;

        let best = root.laps[0];
        for (const lap of root.laps)
            if (fastest ? lap.split < best.split : lap.split > best.split)
                best = lap;
        return best.index;
    }

    // Minutes:seconds, growing to hours for a long run
    function formatShort(ms: real): string {
        const total = Math.max(0, ms);
        const h = Math.floor(total / 3600000);
        const m = Math.floor((total % 3600000) / 60000);
        const s = Math.floor((total % 60000) / 1000);

        if (h > 0)
            return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }

    // Minutes:seconds and hundredths, growing to hours for a long run. Hundredths rather than
    // milliseconds: three digits changing at once is a blur, and nothing here is timed that finely
    function format(ms: real): string {
        const total = Math.max(0, ms);
        const h = Math.floor(total / 3600000);
        const m = Math.floor((total % 3600000) / 60000);
        const s = Math.floor((total % 60000) / 1000);
        const cs = Math.floor((total % 1000) / 10);

        const tail = `${s.toString().padStart(2, "0")}.${cs.toString().padStart(2, "0")}`;
        if (h > 0)
            return `${h}:${m.toString().padStart(2, "0")}:${tail}`;
        return `${m}:${tail}`;
    }

    // Reads the clock rather than the last tick, so a pause is exact rather than up to a frame off
    function now(): real {
        return root.running ? root.accumulated + (Date.now() - root.startedAt) : root.accumulated;
    }

    function start(): void {
        if (root.running)
            return;

        root.startedAt = Date.now();
        root.running = true;
        root.elapsed = root.accumulated;
    }

    function pause(): void {
        if (!root.running)
            return;

        root.accumulated = root.now();
        root.running = false;
        root.elapsed = root.accumulated;
    }

    function toggle(): void {
        if (root.running)
            root.pause();
        else
            root.start();
    }

    // Back to nothing, laps and all
    function reset(): void {
        root.running = false;
        root.accumulated = 0;
        root.startedAt = 0;
        root.elapsed = 0;
        root.laps = [];
    }

    // Marks the reading now. Taking a lap off a stopwatch that was never started would only record
    // a zero, so it is ignored
    function lap(): void {
        if (!root.active)
            return;

        const at = root.now();
        const previous = root.laps.length > 0 ? root.laps[0].at : 0;
        root.laps = [
            {
                index: root.laps.length + 1,
                at,
                split: at - previous
            },
            ...root.laps
        ].slice(0, root.maxLaps);
    }

    // Only runs while the stopwatch does, which is something started on purpose. At the shared
    // decorative rate rather than every screen refresh: hundredths are already past what can be
    // read off a moving number, and this is the one thing in the shell that wants a fast tick
    Timer {
        interval: PowerSaving.frameMs
        repeat: true
        running: root.running
        triggeredOnStart: true

        onTriggered: root.elapsed = root.now()
    }
}
