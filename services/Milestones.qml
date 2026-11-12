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
    readonly property var modes: ["day", "week", "daily", "weekly", "date", "yearly", "interval"]

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
        case "daily":
            return Tr.tr("Daily time");
        case "weekly":
            return Tr.tr("Weekly time");
        case "yearly":
            return Tr.tr("Yearly date");
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

    // A yearly date is stored as MM-DD, optionally followed by HH:mm. A full YYYY-MM-DD is also
    // accepted so a date copied from the one-off field still works; the year is ignored.
    function parseAnnual(value: var): var {
        const text = String(value ?? "").trim();
        const match = /^(?:(\d{4})-)?(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{2}))?$/.exec(text);
        if (!match)
            return null;

        const month = Number(match[2]);
        const day = Number(match[3]);
        const hour = Number(match[4] ?? 0);
        const minute = Number(match[5] ?? 0);
        if (month < 1 || month > 12 || day < 1 || day > 31 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return null;

        // 2000 is a leap year, so 29 February is a valid yearly date while 31 April is not.
        const probe = new Date(2000, month - 1, day);
        if (probe.getMonth() !== month - 1 || probe.getDate() !== day)
            return null;

        return {
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            hasTime: match[4] !== undefined
        };
    }

    function validAnnual(value: var): bool {
        return root.parseAnnual(value) !== null;
    }

    // A repeating daily time is stored as HH:mm. It is meant for a bedtime or another point in
    // the day that should come around again tomorrow rather than on a fixed calendar date.
    function parseClock(value: var): var {
        const match = /^(\d{1,2}):(\d{2})$/.exec(String(value ?? "").trim());
        if (!match)
            return null;

        const hour = Number(match[1]);
        const minute = Number(match[2]);
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return null;

        return {
            hour: hour,
            minute: minute
        };
    }

    function validDaily(value: var): bool {
        return root.parseClock(value) !== null;
    }

    // A weekly time is a weekday name with an optional HH:mm. Without a time it means the end
    // of that day, so "Fri" is the end of the work week even for a long Friday.
    function parseWeekly(value: var): var {
        const match = /^([A-Za-z]{3,9})(?:\s+(\d{1,2}):(\d{2}))?$/.exec(String(value ?? "").trim());
        if (!match)
            return null;

        const days = {
            mon: 0,
            monday: 0,
            tue: 1,
            tues: 1,
            tuesday: 1,
            wed: 2,
            wednesday: 2,
            thu: 3,
            thur: 3,
            thurs: 3,
            thursday: 3,
            fri: 4,
            friday: 4,
            sat: 5,
            saturday: 5,
            sun: 6,
            sunday: 6
        };
        const weekday = days[match[1].toLowerCase()];
        if (weekday === undefined)
            return null;

        const hour = Number(match[2] ?? 23);
        const minute = Number(match[3] ?? 59);
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return null;

        return {
            weekday: weekday,
            hour: hour,
            minute: minute,
            hasTime: match[2] !== undefined
        };
    }

    function validWeekly(value: var): bool {
        return root.parseWeekly(value) !== null;
    }

    function dailyBounds(entry: var, now: double): var {
        const clock = root.parseClock(entry.end || entry.start);
        if (!clock)
            return null;

        const date = new Date(now);
        let endDate = new Date(date.getFullYear(), date.getMonth(), date.getDate(), clock.hour, clock.minute);
        if (endDate.getTime() <= now)
            endDate = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1, clock.hour, clock.minute);

        const startDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate() - 1, clock.hour, clock.minute);
        return {
            start: startDate.getTime(),
            end: endDate.getTime()
        };
    }

    function weeklyBounds(entry: var, now: double): var {
        const weekly = root.parseWeekly(entry.end || entry.start);
        if (!weekly)
            return null;

        const date = new Date(now);
        const offset = (date.getDay() + 6) % 7;
        const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset);
        const hour = weekly.hasTime ? weekly.hour : 23;
        const minute = weekly.hasTime ? weekly.minute : 59;
        let endDate = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + weekly.weekday, hour, minute, weekly.hasTime ? 0 : 59, weekly.hasTime ? 0 : 999);
        if (endDate.getTime() <= now)
            endDate = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + weekly.weekday + 7, hour, minute, weekly.hasTime ? 0 : 59, weekly.hasTime ? 0 : 999);

        const startDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate() - 7, hour, minute, weekly.hasTime ? 0 : 59, weekly.hasTime ? 0 : 999);
        return {
            start: startDate.getTime(),
            end: endDate.getTime()
        };
    }

    // Build this year's occurrence. 29 February falls back to the last day of February in a
    // non-leap year so the countdown still has a date every year.
    function annualOccurrence(annual: var, year: int): double {
        const lastDay = new Date(year, annual.month, 0).getDate();
        const day = Math.min(annual.day, lastDay);
        const date = new Date(year, annual.month - 1, day, annual.hasTime ? annual.hour : 23, annual.hasTime ? annual.minute : 59, annual.hasTime ? 0 : 59, annual.hasTime ? 0 : 999);
        return date.getTime();
    }

    // A yearly event is measured from its previous occurrence to the next one, so the bar resets
    // shortly after the day passes and always points at the upcoming year instead of staying done.
    function annualBounds(entry: var, now: double): var {
        const annual = root.parseAnnual(entry.end || entry.start);
        if (!annual)
            return null;

        let year = new Date(now).getFullYear();
        let end = root.annualOccurrence(annual, year);
        if (end <= now) {
            year += 1;
            end = root.annualOccurrence(annual, year);
        }

        return {
            start: root.annualOccurrence(annual, year - 1),
            end: end
        };
    }

    function bounds(entry: var, now: double): var {
        if (entry.mode === "yearly")
            return root.annualBounds(entry, now);
        if (entry.mode === "daily")
            return root.dailyBounds(entry, now);
        if (entry.mode === "weekly")
            return root.weeklyBounds(entry, now);

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

    function targetFor(entry: var, now: double): string {
        let end = NaN;
        if (entry?.mode === "date")
            end = root.parseTime(entry.end || entry.start, true);
        else if (entry?.mode === "daily" || entry?.mode === "weekly" || entry?.mode === "yearly")
            end = root.bounds(entry, now)?.end ?? NaN;
        else if (entry?.mode === "interval")
            end = root.parseTime(entry.end, true);

        if (!Number.isFinite(end))
            return "";
        if (entry?.mode === "daily")
            return Qt.formatTime(new Date(end), "HH:mm");
        if (entry?.mode === "weekly") {
            const weekly = root.parseWeekly(entry.end || entry.start);
            const date = new Date(end);
            const day = Qt.formatDate(date, "ddd");
            return weekly?.hasTime ? `${day} ${Qt.formatTime(date, "HH:mm")}` : day;
        }
        return Qt.formatDate(new Date(end), entry?.mode === "yearly" ? "d MMM yyyy" : "d MMM");
    }

    function describe(entry: var): string {
        const target = root.targetFor(entry, Date.now());
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
            target: entry.mode === "daily" || entry.mode === "weekly" || entry.mode === "date" || entry.mode === "yearly" || entry.mode === "interval" ? root.targetFor(entry, now) : ""
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
