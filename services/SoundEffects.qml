pragma Singleton

import Quickshell
import Caelestia.Config

// NOTE(fork): short system sound effects (camera click, lock/unlock, ...), played through the
// system's own XDG sound theme rather than bundling audio files. Each call is a detached,
// one-off paplay so overlapping sounds (e.g. a quick run of volume ticks) don't cut each other off.
Singleton {
    id: root

    readonly property var paths: ({
            cameraClick: "/usr/share/sounds/freedesktop/stereo/camera-shutter.oga",
            chargingStarted: "/usr/share/sounds/freedesktop/stereo/power-plug.oga",
            volumeTick: "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga",
            screenLock: "/usr/share/sounds/freedesktop/stereo/bell.oga",
            screenUnlock: "/usr/share/sounds/freedesktop/stereo/complete.oga",
            lowBattery: "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga",
            screenRecord: "/usr/share/sounds/freedesktop/stereo/screen-capture.oga",
            timerEnd: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        })

    // Status alerts use the notification volume; direct interaction feedback uses the SFX one
    readonly property var notificationEvents: ["lowBattery", "chargingStarted"]

    function enabledFor(event: string): bool {
        // The config node lives in the C++ plugin, so it is absent when the loaded plugin
        // is older than this config (a stale dev build). A sound effect is cosmetic and
        // must never be able to break the flow that triggered it, so a missing node just
        // reads as disabled rather than throwing on the next line.
        const cfg = GlobalConfig.services?.soundEffects;
        if (!cfg || !cfg.enabled)
            return false;
        return cfg[event] ?? true;
    }

    function play(event: string): void {
        if (!root.enabledFor(event))
            return;

        const path = root.paths[event];
        if (!path)
            return;

        const cfg = GlobalConfig.services.soundEffects;
        const volume = root.notificationEvents.includes(event) ? cfg.notificationVolume : cfg.sfxVolume;
        const scaled = Math.round(Math.max(0, Math.min(1, volume)) * 65536);
        Quickshell.execDetached(["paplay", "--volume", String(scaled), path]);
    }

    // A timer's alarm is part of what was asked for rather than an incidental effect, so it plays even with the
    // sound effects switched off - at the notification volume, since it is an alert rather than feedback
    function playAlert(event: string): void {
        const path = root.paths[event];
        if (!path)
            return;

        const volume = GlobalConfig.services?.soundEffects?.notificationVolume ?? 0.5;
        const scaled = Math.round(Math.max(0, Math.min(1, volume)) * 65536);
        Quickshell.execDetached(["paplay", "--volume", String(scaled), path]);
    }
}
