pragma Singleton

import QtQuick
import Quickshell
import Caelestia.I18n

// The utilities panel's timer: a plain countdown to however long was picked, kept apart from the desktop's focus
// timer so the two can run without treading on each other. It lives in a service because the panel it is started from
// is torn down when the sidebar closes, while the countdown has to keep running - and end up ringing - either way.
Singleton {
    id: root

    // How long the timer was set for, what is left of it, and whether it is counting down
    property int durationSecs: 5 * 60
    property int remaining: durationSecs
    property bool running: false

    // When the current run is due to end, as Date.now() milliseconds. Every tick reads what is left off the clock
    // rather than counting beats, so the count stays right when the shell was busy or the machine slept.
    property double endAt: 0

    // Set the moment the countdown runs out, and kept until a new timer is started or the finished one dismissed, so
    // the ring in the bar shows that it rang instead of vanishing as the last second ticks away
    property bool finished: false

    // Running, paused part way through, or rung and not yet dismissed
    readonly property bool active: root.running || root.finished || (root.remaining > 0 && root.remaining < root.durationSecs)
    readonly property real progress: root.durationSecs > 0 ? 1 - root.remaining / root.durationSecs : (root.finished ? 1 : 0)
    readonly property string display: root.format(root.remaining)
    readonly property string durationDisplay: root.format(root.durationSecs)
    // Always all three units, which is what the panel's ring reads and what gets typed back into it
    readonly property string displayHms: root.hms(root.remaining)

    // Minutes:seconds, growing to hours:minutes:seconds for a long run
    function format(secs: int): string {
        const total = Math.max(0, secs);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;

        if (h > 0)
            return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }

    // Hours:minutes:seconds, zero padded
    function hms(secs: int): string {
        const total = Math.max(0, secs);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;

        return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
    }

    // Picks how long a run lasts, without starting one. Setting a time also clears a count that has already rung,
    // so the new time is what the panel and the bar show rather than the finished one's zero
    function setDuration(secs: int): void {
        if (root.running)
            return;

        root.durationSecs = Math.max(1, Math.round(secs));
        root.finished = false;
        root.remaining = root.durationSecs;
    }

    // Starts a fresh run, of `secs` if one is given and of the set duration otherwise
    function start(secs: int): void {
        root.finished = false;
        if (secs > 0)
            root.durationSecs = Math.max(1, Math.round(secs));
        root.remaining = root.durationSecs;
        root.endAt = Date.now() + root.remaining * 1000;
        root.running = true;
    }

    function pause(): void {
        if (!root.running)
            return;

        root.running = false;
        // Frozen at what the clock says, so a pause is exact rather than up to a tick off
        root.remaining = Math.max(1, Math.round((root.endAt - Date.now()) / 1000));
    }

    function resume(): void {
        if (root.running || root.finished || root.remaining <= 0)
            return;

        root.endAt = Date.now() + root.remaining * 1000;
        root.running = true;
    }

    // One button for the lot: it starts what was set, pauses what is running, picks a paused one back up, and starts
    // over once it has rung
    function toggle(): void {
        if (root.finished)
            root.start();
        else if (root.running)
            root.pause();
        else
            root.resume();
    }

    // Back to the set duration, ready to start
    function reset(): void {
        root.running = false;
        root.finished = false;
        root.remaining = root.durationSecs;
    }

    // Clears a timer that has rung off the bar, without setting another one
    function dismiss(): void {
        if (!root.finished)
            return;

        root.reset();
    }

    Timer {
        // Twice a second, so the count drops on the second rather than up to a beat late
        interval: 500
        repeat: true
        running: root.running
        triggeredOnStart: true

        onTriggered: {
            const left = Math.round((root.endAt - Date.now()) / 1000);
            if (left > 0) {
                root.remaining = left;
                return;
            }

            root.remaining = 0;
            root.running = false;
            root.finished = true;

            // An alarm, so it rings whether or not incidental sound effects are switched on
            SoundEffects.playAlert("timerEnd");

            // And a notification, for when the sound is off or nobody is at the machine: it goes through the shell's
            // own notification server, so it waits in the sidebar after its popup has gone
            Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-i", "alarm", "-u", "normal", Tr.tr("Timer finished"), Tr.tr("%1 timer is up").arg(root.durationDisplay)]);
        }
    }
}
