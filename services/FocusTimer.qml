pragma Singleton

import QtQuick
import Quickshell

// The desktop focus timer's state. It lives here rather than in the card so the countdown keeps going while the
// card is unloaded (the desktop widgets are removed entirely while windows cover the wallpaper).
Singleton {
    id: root

    property int durationSecs: 25 * 60
    property int remaining: durationSecs
    property bool running: false

    readonly property string display: {
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
    }

    function toggle(): void {
        if (remaining <= 0)
            remaining = durationSecs;
        running = !running;
    }

    function reset(): void {
        running = false;
        remaining = durationSecs;
    }

    function adjust(mins: int): void {
        if (running)
            return;
        durationSecs = Math.max(60, durationSecs + mins * 60);
        remaining = durationSecs;
    }

    // Only ticks while a session is actually running
    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0)
                root.running = false;
        }
    }
}
