pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n

// The progress card's targets. A target is either a built-in day/week window or a custom date
// range from Settings; keeping the boundary and formatting logic here means the card, its
// previews and the settings list all describe a milestone the same way.
Singleton {
    id: root

    readonly property var config: GlobalConfig.background.desktopWidgets
    // Four milestones fit the tallest card without turning it into a list that cannot be
    // scrolled on the desktop.
    readonly property int maxItems: 4
    readonly property var modes: ["day", "week", "date", "interval"]

    readonly property var entries: {
        const values = root.config.progressEntries?.values ?? [];
        const out = [];
        for (let i = 0; i < values.length && out.length < root.maxItems; i++) {
            const item = values[i];
            if (!item || item.enabled === false)
                continue;

            out.push({
                index: i,
                label: String(item.label ?? "").trim(),
                mode: root.modeFor(item.mode),
                start: String(item.start ?? "").trim(),
                end: String(item.end ?? "").trim()
            });
        }
        return out;
    }

    readonly property bool hasEntries: entries.length > 0

    function modeFor(mode: var): string {
        return root.modes.indexOf(String(mode ?? "")) >= 0 ? String(mode) : "date";
    }

    function labelFor(entry: var): string {
        const label = String(entry?.label ?? "").trim();
        if (label !== "")
            return label;

        switch (entry?.mode) {
        case "day":
            return Tr.tr("End of day");
        case "week":
            return Tr.tr("End of week");
        case "interval":
            return Tr.tr("Interval");
        default:
            return Tr.tr("Target date");
        }
    }

    // Accepts a plain date or a date and time, both in local time. A date-only end means the
    // whole of that day, which is what "Christmas" or "end of exams" should include.
    function parseTime(value: var, endOfDay: bool): double {
        const text = String(value ?? "").trim();
        if (text === "")
            return NaN;

        const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
        if (dateOnly) {
            const year = Number(dateOnly[1]);
            const month = Number(dateOnly[2]);
            const day = Number(dateOnly[3]);
            const date = new Date(year, month - 1, day, endOfDay ? 23 : 0, endOfDay ? 59 : 0, endOfDay ? 59 : 0, endOfDay ? 999 : 0);
            if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day)
                return NaN;
            return date.getTime();
        }

        // QML's parser is happier with the ISO separator; a space is what people naturally type.
        const parsed = Date.parse(text.replace(" ", "T"));
        return Number.isFinite(parsed) ? parsed : NaN;
    }

    function validDate(value: var, endOfDay: bool): bool {
        return Number.isFinite(root.parseTime(value, endOfDay));
    }

    function bounds(entry: var, now: double): var {
        const date = new Date(now);

        if (entry.mode === "day") {
            const start = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
            const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
            return {
                start: start,
                end: end
            };
        }

        if (entry.mode === "week") {
            const offset = (date.getDay() + 6) % 7;
            const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset).getTime();
            const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset + 7).getTime();
            return {
                start: start,
                end: end
            };
        }

        let start = NaN;
        let end = NaN;
        if (entry.mode === "date") {
            end = root.parseTime(entry.end || entry.start, true);
            start = root.parseTime(entry.start, false);
            // A birthday or Christmas has no obvious start, so it runs through the year up to
            // the day itself.
            if (Number.isFinite(end) && !Number.isFinite(start))
                start = new Date(new Date(end).getFullYear(), 0, 1).getTime();
        } else {
            start = root.parseTime(entry.start, false);
            end = root.parseTime(entry.end, true);
        }

        if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start)
            return null;

        return {
            start: start,
            end: end
        };
    }

    function duration(ms: double): string {
        const minutes = Math.max(0, Math.ceil(ms / 60000));
        if (minutes <= 0)
            return Tr.tr("under a minute");
        if (minutes < 60)
            return Tr.tr("%1 min").arg(minutes);

        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        if (hours < 24)
            return mins > 0 ? Tr.tr("%1 h %2 min").arg(hours).arg(mins) : Tr.tr("%1 h").arg(hours);

        const days = Math.floor(hours / 24);
        const hrs = hours % 24;
        return hrs > 0 ? Tr.tr("%1 d %2 h").arg(days).arg(hrs) : Tr.tr("%1 d").arg(days);
    }

    function targetFor(entry: var): string {
        let end = NaN;
        if (entry?.mode === "date")
            end = root.parseTime(entry.end || entry.start, true);
        else if (entry?.mode === "interval")
            end = root.parseTime(entry.end, true);

        return Number.isFinite(end) ? Qt.formatDate(new Date(end), "d MMM") : "";
    }

    function describe(entry: var): string {
        const target = root.targetFor(entry);
        return target === "" ? root.labelFor(entry) : `${root.labelFor(entry)} · ${target}`;
    }

    function resolve(entry: var, now: double): var {
        const span = root.bounds(entry, now);
        if (!span)
            return null;

        const total = span.end - span.start;
        const fraction = Math.max(0, Math.min(1, (now - span.start) / total));
        const remaining = span.end - now;
        const before = span.start - now;
        let status;
        if (before > 0)
            status = Tr.tr("Starts in %1").arg(root.duration(before));
        else if (remaining <= 0)
            status = Tr.tr("Done");
        else
            status = Tr.tr("%1 left").arg(root.duration(remaining));

        return {
            index: entry.index,
            label: root.labelFor(entry),
            mode: entry.mode,
            fraction: fraction,
            percent: Math.round(fraction * 100),
            done: remaining <= 0,
            status: status,
            target: entry.mode === "date" || entry.mode === "interval" ? root.targetFor(entry) : ""
        };
    }

    function evaluate(now: double): var {
        const out = [];
        for (const entry of root.entries) {
            const item = root.resolve(entry, now);
            if (item)
                out.push(item);
        }
        return out;
    }
}
