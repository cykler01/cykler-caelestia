pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// The signed-in Claude account's usage limits - the rolling 5-hour window and the week - for the
// desktop widget. Fetched by scripts/caelestia-claude-limits.py from the token Claude Code keeps,
// every few minutes while a card holds a reference (components/misc/Ref.qml). The last reading is
// cached, so a card has something to show the moment it appears.
Singleton {
    id: root

    property int refCount: 0

    // { used: 0-100, resetsAt: Date | null }, or null when there is no reading for that window
    property var fiveHour: null
    property var weekly: null
    property string plan
    // When the reading was taken, in ms since the epoch; 0 for none yet
    property real fetchedAt: 0
    // "", or why there is no fresh reading: "signed-out", "expired", "network", "http"
    property string error
    property string errorMessage
    readonly property bool loaded: fiveHour !== null || weekly !== null
    readonly property bool busy: proc.running

    readonly property int interval: 5 * 60 * 1000

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    function parseWindow(w: var): var {
        if (!w || typeof w.used !== "number")
            return null;
        return {
            used: Math.max(0, Math.min(100, w.used)),
            resetsAt: w.resetsAt ? new Date(w.resetsAt * 1000) : null
        };
    }

    function apply(msg: var, fromCache: bool): void {
        fiveHour = parseWindow(msg.fiveHour);
        weekly = parseWindow(msg.weekly);
        plan = msg.plan ?? "";
        fetchedAt = (msg.fetchedAt ?? 0) * 1000;
        if (!fromCache) {
            error = "";
            errorMessage = "";
            cache.setText(JSON.stringify(msg));
        }
    }

    // "2 h 14 min", "3 d 5 h": how long until a window starts over
    function untilLabel(d: var): string {
        if (!d)
            return Tr.tr("Not started");
        const mins = Math.max(0, Math.round((d.getTime() - Time.date.getTime()) / 60000));
        if (mins < 60)
            return Tr.tr("%1 min").arg(Math.max(1, mins));
        const h = Math.floor(mins / 60);
        if (h < 24)
            return mins % 60 === 0 ? Tr.tr("%1 h").arg(h) : Tr.tr("%1 h %2 min").arg(h).arg(mins % 60);
        const days = Math.floor(h / 24);
        return h % 24 === 0 ? Tr.tr("%1 d").arg(days) : Tr.tr("%1 d %2 h").arg(days).arg(h % 24);
    }

    // When a window resets, as a clock time today or a weekday and time later on
    function resetLabel(d: var): string {
        if (!d)
            return Tr.tr("Not started");
        const time = Qt.formatTime(d, Units.twelveHourClock ? "h:mm AP" : "HH:mm");
        const today = Time.date;
        if (d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate())
            return time;
        return `${Tr.formatDateTime(d, "ddd")} ${time}`;
    }

    function planName(): string {
        if (plan === "max")
            return "Max";
        if (plan === "pro")
            return "Pro";
        if (plan === "team")
            return "Team";
        if (plan === "enterprise")
            return "Enterprise";
        return plan;
    }

    onRefCountChanged: {
        if (refCount > 0 && !pollTimer.running) {
            pollTimer.start();
            // A reading under a minute old is still good, so cards coming and going don't refetch.
            // A failed fetch leaves it as it was, so the next card to appear tries again
            if (Date.now() - fetchedAt > 60000)
                refresh();
        } else if (refCount <= 0) {
            pollTimer.stop();
        }
    }

    Process {
        id: proc

        command: ["python3", Quickshell.shellPath("scripts/caelestia-claude-limits.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                let msg;
                try {
                    msg = JSON.parse(text.trim().split("\n").pop());
                } catch (e) {
                    root.error = "http";
                    root.errorMessage = Tr.tr("Couldn't read the usage");
                    return;
                }
                if (msg.type === "usage") {
                    root.apply(msg, false);
                } else {
                    root.error = msg.reason ?? "http";
                    root.errorMessage = msg.message ?? "";
                }
            }
        }
    }

    Timer {
        id: pollTimer

        interval: root.interval
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: cache

        path: `${Paths.cache}/claude-limits.json`
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const msg = JSON.parse(text());
                if (msg?.type === "usage" && !root.loaded)
                    root.apply(msg, true);
            } catch (e) {
                // Nothing saved yet
            }
        }
    }
}
