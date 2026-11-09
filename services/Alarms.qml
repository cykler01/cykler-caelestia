pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.utils

// NOTE(fork): alarms - a time of day to be woken at, rather than a length to be counted down (see
// CountdownTimer) or counted up (Stopwatch). They sit in the third tab of the timer panel.
//
// Each alarm carries the moment it is next due as a plain timestamp rather than being worked out
// from the clock on every tick: setting one, enabling it or letting it ring is what recomputes it.
// That is what keeps an alarm set for 09:00 at two in the afternoon from going off the instant it
// is saved - it is due tomorrow, and says so.
//
// A shell that is not running cannot wake anyone, the same as every other in-shell timer here, so
// a missed alarm is simply late: it does not fire on the way back up, it moves on to its next turn.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/alarms.json`

    // { id, hour, minute, label, enabled, days, nextAt }. `days` holds weekday numbers the way
    // JavaScript counts them (0 is Sunday); empty means it rings once and switches itself off.
    property var alarms: []

    // The alarm going off right now, if any. Held until it is dismissed or snoozed, so the panel
    // can say which one it was even after the sound has finished
    property string ringingId: ""
    readonly property bool ringing: root.ringingId !== ""
    readonly property var ringingAlarm: root.byId(root.ringingId)

    // How long the snooze button puts it off for
    readonly property int snoozeMinutes: 5
    // An alarm nobody is there to dismiss stops ringing on its own rather than sitting there lit
    // up until someone comes back to the machine
    readonly property int giveUpMinutes: 5

    // The soonest alarm still to come, which is what the panel leads with
    readonly property var nextAlarm: {
        const due = root.alarms.filter(a => a.enabled && a.nextAt > 0);
        if (due.length === 0)
            return null;
        return due.reduce((soonest, a) => a.nextAt < soonest.nextAt ? a : soonest);
    }

    function uid(): string {
        return `${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`;
    }

    function byId(id: string): var {
        return root.alarms.find(a => a.id === id) ?? null;
    }

    // When an alarm set for this time of day next comes round, starting from `after`. A repeating
    // one looks ahead for the first weekday it is set for; one with no days takes the next time
    // that hour and minute come round at all
    function dueAfter(alarm: var, after: real): real {
        const from = new Date(after);
        for (let i = 0; i < 8; i++) {
            const at = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i, alarm.hour, alarm.minute, 0, 0);
            if (at.getTime() <= after)
                continue;
            if (alarm.days.length > 0 && !alarm.days.includes(at.getDay()))
                continue;
            return at.getTime();
        }
        return 0;
    }

    // How long until it rings, worded for the panel: "in 7 h 20 min", down to the minute. `tick` is
    // not read: it is there for the caller to pass the current minute, so a binding on this follows
    // the clock instead of going stale the moment it is first worked out
    function untilText(at: real, tick: int): string {
        const mins = Math.max(0, Math.round((at - Date.now()) / 60000));
        const h = Math.floor(mins / 60);
        const m = mins % 60;

        if (h > 0 && m > 0)
            // TRANSLATORS: %1 = whole hours, %2 = the minutes left over, e.g. "7 h 20 min"
            return Tr.trCtx("in %1 h %2 min", "how long until an alarm rings").arg(h).arg(m);
        if (h > 0)
            return Tr.trCtx("in %1 h", "how long until an alarm rings").arg(h);
        if (m > 0)
            return Tr.trCtx("in %1 min", "how long until an alarm rings").arg(m);
        return Tr.trCtx("in under a minute", "how long until an alarm rings");
    }

    // The time of day an alarm is set for, in whichever clock the shell is set to
    function timeText(alarm: var): string {
        const at = new Date();
        at.setHours(alarm.hour, alarm.minute, 0, 0);
        return Qt.formatTime(at, Units.twelveHourClock ? "h:mm A" : "HH:mm");
    }

    function save(): void {
        const data = JSON.stringify({
            version: 1,
            alarms: root.alarms
        });
        // Deferred so writing right after a failed load (the file not existing yet) is safe, the
        // same as the other services that seed a state file
        Qt.callLater(() => storage.setText(data));
    }

    // Rewrites one alarm through `change`, recomputing when it is next due, and saves
    function update(id: string, change: var): void {
        root.alarms = root.alarms.map(a => {
            if (a.id !== id)
                return a;

            const next = Object.assign({}, a, change);
            next.nextAt = next.enabled ? root.dueAfter(next, Date.now()) : 0;
            return next;
        });
        root.save();
    }

    // A new alarm at the next whole hour, which is as good a guess as any and saves setting it
    // from midnight every time
    function add(): string {
        const at = new Date(Date.now() + 3600000);
        const alarm = {
            id: root.uid(),
            hour: at.getHours(),
            minute: 0,
            label: "",
            enabled: true,
            days: [],
            nextAt: 0
        };
        alarm.nextAt = root.dueAfter(alarm, Date.now());

        root.alarms = [...root.alarms, alarm];
        root.save();
        return alarm.id;
    }

    function remove(id: string): void {
        if (root.ringingId === id)
            root.ringingId = "";

        root.alarms = root.alarms.filter(a => a.id !== id);
        root.save();
    }

    function setTime(id: string, hour: int, minute: int): void {
        root.update(id, {
            hour: Math.max(0, Math.min(23, hour)),
            minute: Math.max(0, Math.min(59, minute))
        });
    }

    function setLabel(id: string, label: string): void {
        root.update(id, {
            label: label.trim()
        });
    }

    function setEnabled(id: string, enabled: bool): void {
        if (!enabled && root.ringingId === id)
            root.ringingId = "";

        root.update(id, {
            enabled
        });
    }

    // Turns one weekday on or off. An alarm with no days left rings once and stops
    function toggleDay(id: string, day: int): void {
        const alarm = root.byId(id);
        if (!alarm)
            return;

        const days = alarm.days.includes(day) ? alarm.days.filter(d => d !== day) : [...alarm.days, day].sort();
        root.update(id, {
            days
        });
    }

    // A lone number is an hour, "7:30" is half past seven. Anything else comes back null, so the
    // caller can leave the alarm as it was
    function parseTime(text: string): var {
        const value = text.trim();
        if (value === "")
            return null;

        const parts = value.split(":");
        if (parts.length > 2)
            return null;

        const nums = parts.map(part => Number(part.trim()));
        if (nums.some(num => isNaN(num) || num < 0))
            return null;

        const hour = Math.floor(nums[0]);
        const minute = nums.length > 1 ? Math.floor(nums[1]) : 0;
        if (hour > 23 || minute > 59)
            return null;

        return {
            hour,
            minute
        };
    }

    function dismiss(): void {
        root.ringingId = "";
    }

    // Puts the one that is ringing off for a few minutes, without touching when it is due after
    // that: a repeating alarm snoozed on Monday still rings on Tuesday, since letting the snooze
    // ring is what works out its next turn.
    //
    // It is switched back on along the way: a one-shot alarm has already turned itself off by the
    // time anyone can reach the snooze button, and a snooze that never rings is not a snooze
    function snooze(): void {
        const alarm = root.ringingAlarm;
        root.ringingId = "";
        if (!alarm)
            return;

        root.alarms = root.alarms.map(a => a.id === alarm.id ? Object.assign({}, a, {
            enabled: true,
            nextAt: Date.now() + root.snoozeMinutes * 60000
        }) : a);
        root.save();
    }

    function ring(alarm: var): void {
        root.ringingId = alarm.id;
        giveUpTimer.restart();

        // An alarm is the whole point of the thing, so it sounds whether or not incidental sound
        // effects are switched on
        SoundEffects.playAlert("timerEnd");
        Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", Tr.tr("Alarm"), alarm.label || root.timeText(alarm)]);
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.alarms"
        defaultLogLevel: LoggingCategory.Warning
    }

    // Checked often enough that an alarm is never more than a few seconds late, and cheaply
    // enough that it costs nothing to leave running: a comparison per alarm
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const now = Date.now();
            let due = null;
            let changed = false;

            root.alarms = root.alarms.map(a => {
                if (!a.enabled || a.nextAt <= 0 || a.nextAt > now)
                    return a;

                // The first one due this tick is the one that rings; another at the same minute
                // simply moves on to its next turn
                if (!due)
                    due = a;
                changed = true;

                // One with no days has had its turn; a repeating one moves on to the next
                const next = Object.assign({}, a);
                if (a.days.length === 0) {
                    next.enabled = false;
                    next.nextAt = 0;
                } else {
                    next.nextAt = root.dueAfter(a, now);
                }
                return next;
            });

            if (changed)
                root.save();
            if (due)
                root.ring(due);
        }
    }

    Timer {
        id: giveUpTimer

        interval: root.giveUpMinutes * 60000
        onTriggered: root.ringingId = ""
    }

    FileView {
        id: storage

        printErrors: false
        path: root.storePath
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const loaded = Array.isArray(data?.alarms) ? data.alarms : [];
                const now = Date.now();

                // Anything due while the shell was not running has missed its turn, so each one is
                // put forward to its next rather than going off all at once on the way up
                root.alarms = loaded.map(a => {
                    const alarm = {
                        id: a.id ?? root.uid(),
                        hour: Math.max(0, Math.min(23, a.hour ?? 0)),
                        minute: Math.max(0, Math.min(59, a.minute ?? 0)),
                        label: a.label ?? "",
                        enabled: a.enabled ?? true,
                        days: Array.isArray(a.days) ? a.days : [],
                        nextAt: 0
                    };
                    alarm.nextAt = alarm.enabled ? root.dueAfter(alarm, now) : 0;
                    return alarm;
                });
            } catch (e) {
                console.warn(lc, `Unable to read the alarms: ${e}`);
            }
        }
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the alarms: ${err}`);
        }
    }
}
