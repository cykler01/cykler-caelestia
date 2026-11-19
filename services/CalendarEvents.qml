pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// The user's calendar events, for the dashboard's month grid and the event widgets on the
// desktop, the dashboard and the lock screen.
//
// Read through evolution-data-server, which is where GNOME Calendar keeps its calendars, by
// scripts/caelestia-calendar.py: local calendars, online accounts and the contacts' birthdays,
// recurring events already expanded, only the calendars ticked in GNOME Calendar's sidebar,
// each in the colour it has there. The helper stays running while something holds a reference
// (see components/misc/Ref.qml) and pushes a fresh list whenever a calendar changes, so an event
// added in GNOME Calendar shows up without a refresh.
//
// Every event is one of three kinds, which decides where it shows and in what colour:
//
//   regular  the routine - lessons, standups, the gym. Repeats daily, weekly or monthly. Left off
//            the calendar and the event lists, which would otherwise be nothing but these, and
//            drawn in grey on the day's progress, where they are the shape of the day
//   special  one-offs that matter - an appointment, a deadline, a trip. Blue, everywhere
//   rare     comes round once a year - birthdays, anniversaries, holidays. Green, everywhere
//
// Sorted event by event from how often it repeats, unless the calendar it is in has been given
// a kind of its own in the settings (Config.dashboard.calendarTypes), for a timetable entered as
// one-offs, say, or a holiday calendar that lists each year's dates separately.
//
// The helper watches a window of dates rather than everything: always the next month from
// today, for the widgets listing what is coming up, stretched to take in whichever month the
// dashboard's grid is showing (focusMonth()) with the weeks either side of it.
Singleton {
    id: root

    property int refCount: 0

    // False where evolution-data-server or its Python bindings are missing, so the calendar can
    // fall back to a plain grid rather than waiting on events that will never come
    property bool available: true
    // Whether a list has come back yet, so "no events" can be told from "not read yet"
    property bool loaded

    // uid -> { name, colour, backend }
    property var calendars: ({})
    // The last list the helper sent, kept so a change of kinds in the settings can re-sort it
    // without asking again
    property var lastMessage: null
    // [{ uid, rid, calendar, summary, location, start: Date, end: Date, allDay, freq, kind, colour, calendarName }],
    // sorted by start. All-day events start and end at local midnight, the end exclusive
    property var events: []
    // "yyyy-MM-dd" -> the events touching that day, all-day first and then by start. Every
    // kind; shownOn() leaves the regular ones out
    property var byDay: ({})

    // The settings' "<calendar uid>=<kind>" entries. Stored as one ';'-separated string (see
    // dashboardconfig.hpp for why it is not a list)
    readonly property list<string> kindEntries: (GlobalConfig.dashboard.calendarTypes ?? "").split(";").filter(e => e !== "")

    // Calendar uid -> the kind set for it in the settings
    readonly property var kindOverrides: {
        const out = {};
        for (const entry of kindEntries) {
            const i = entry.lastIndexOf("=");
            if (i > 0 && kinds.includes(entry.slice(i + 1)))
                out[entry.slice(0, i)] = entry.slice(i + 1);
        }
        return out;
    }
    readonly property list<string> kinds: ["regular", "special", "rare"]

    // The month the dashboard's grid is on, as [year, month]
    property var focus: {
        const now = new Date();
        return [now.getFullYear(), now.getMonth()];
    }

    // How far ahead the widgets look
    readonly property int lookahead: 30

    // The window the helper is asked for, as "yyyy-MM-dd yyyy-MM-dd". Read through Time so it
    // moves on at midnight; a minute's tick that changes nothing leaves the string as it was
    readonly property string range: {
        const now = Time.date;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const [year, month] = root.focus;
        const from = new Date(Math.min(new Date(year, month, 1 - 14), new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)));
        const to = new Date(Math.max(new Date(year, month + 1, 14), new Date(today.getFullYear(), today.getMonth(), today.getDate() + root.lookahead)));
        return `${key(from)} ${key(to)}`;
    }

    readonly property bool enabled: GlobalConfig.dashboard.calendarEvents
    readonly property bool wanted: enabled && available && refCount > 0
    // Whether anything can be shown at all, for a widget deciding between events and a note
    readonly property bool ready: enabled && available && loaded

    // What is still to come, soonest first: events not over yet within the lookahead, those
    // already under way included. Not the regular ones
    readonly property var upcoming: {
        const now = Time.date.getTime();
        const horizon = now + lookahead * 86400000;
        return events.filter(e => e.kind !== "regular" && e.end.getTime() > now && e.start.getTime() < horizon);
    }
    // Today's special and rare events, all-day first, those already over included
    readonly property var today: {
        void byDay;
        return shownOn(Time.date);
    }
    // Everything on today, the routine included, for the day's progress
    readonly property var todayAll: {
        void byDay;
        return eventsOn(Time.date);
    }
    // The next event with a time to it, or failing that the next of any kind
    readonly property var next: upcoming.find(e => !e.allDay) ?? upcoming[0] ?? null

    function pad(n: int): string {
        return n < 10 ? `0${n}` : `${n}`;
    }

    function key(d: date): string {
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function focusMonth(year: int, month: int): void {
        if (focus[0] !== year || focus[1] !== month)
            focus = [year, month];
    }

    // Every event on the day `d`, regular ones included
    function eventsOn(d: date): var {
        return byDay[key(d)] ?? [];
    }

    // The events the calendar and the event lists show on the day `d`: the special and rare ones
    function shownOn(d: date): var {
        return eventsOn(d).filter(e => e.kind !== "regular");
    }

    // Which kind an event is: the calendar's own if the settings give it one, otherwise from how
    // often it repeats. The birthdays calendar, and calendars named for holidays, are rare
    function kindOf(ev: var, cal: var): string {
        const set = kindOverrides[ev.calendar];
        if (set)
            return set;
        if (cal?.backend === "contacts" || /holiday|feiertag|festiv|férié|vacanz|feriado/i.test(cal?.name ?? ""))
            return "rare";
        if (ev.freq === "yearly")
            return "rare";
        if (ev.freq)
            return "regular";
        return "special";
    }

    function kindName(kind: string): string {
        if (kind === "regular")
            return Tr.tr("Regular");
        if (kind === "rare")
            return Tr.tr("Rare");
        return Tr.tr("Special");
    }

    // Grey for the routine, blue for one-offs, green for once a year. Fixed hues rather than the
    // scheme's, so the three always read as three, in a lighter or deeper shade to suit the mode
    function kindColour(kind: string): color {
        if (kind === "regular")
            return Colours.palette.m3outline;
        if (kind === "rare")
            return Colours.light ? "#1e8e3e" : "#81c995";
        return Colours.light ? "#1a73e8" : "#8ab4f8";
    }

    // Sets the kind every event in a calendar counts as, or "auto" to sort them one by one again
    function setCalendarKind(uid: string, kind: string): void {
        const list = kindEntries.filter(e => !e.startsWith(`${uid}=`));
        if (kinds.includes(kind))
            list.push(`${uid}=${kind}`);
        GlobalConfig.dashboard.calendarTypes = list.join(";");
    }

    // Which day of a multi-day event `d` is, as [n, of], or null for a single-day one
    function spanOf(ev: var, d: date): var {
        const days = dayCount(ev);
        if (days <= 1)
            return null;
        const first = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate());
        const n = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - first) / 86400000) + 1;
        return [n, days];
    }

    function dayCount(ev: var): int {
        const first = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate());
        const last = lastDay(ev);
        return Math.round((last - first) / 86400000) + 1;
    }

    // The last local day an event touches. Its end is exclusive, so one ending at midnight
    // does not spill into the next day
    function lastDay(ev: var): date {
        const end = new Date(Math.max(ev.start.getTime(), ev.end.getTime() - 1));
        return new Date(end.getFullYear(), end.getMonth(), end.getDate());
    }

    function isOngoing(ev: var): bool {
        const now = Time.date.getTime();
        return !ev.allDay && ev.start.getTime() <= now && now < ev.end.getTime();
    }

    function isOver(ev: var): bool {
        return !ev.allDay && ev.end.getTime() <= Time.date.getTime();
    }

    // ---- How the widgets word things --------------------------------------------------------

    function colourOf(ev: var): color {
        return kindColour(ev?.kind ?? "special");
    }

    // The colour a day is washed in on the calendar: special beats rare, and a day with only
    // regular events has none
    function dayColour(d: date): var {
        const shown = shownOn(d);
        if (shown.length === 0)
            return null;
        return kindColour(shown.some(e => e.kind === "special") ? "special" : "rare");
    }

    function titleOf(ev: var): string {
        return ev?.summary || Tr.tr("Untitled event");
    }

    function formatTime(d: date): string {
        return Qt.formatTime(d, Units.twelveHourClock ? "h:mm AP" : "HH:mm");
    }

    // Days from today to `d`: 0 today, 1 tomorrow, -1 yesterday
    function dayDiff(d: date): int {
        const now = Time.date;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
    }

    // "Today", "Tomorrow", "Thursday" within the week, "Thu 3 Dec" past it
    function dayLabel(d: date): string {
        const diff = dayDiff(d);
        if (diff === 0)
            return Tr.tr("Today");
        if (diff === 1)
            return Tr.tr("Tomorrow");
        if (diff === -1)
            return Tr.tr("Yesterday");
        if (diff > 1 && diff < 7)
            return Tr.formatDateTime(d, "dddd");
        return Tr.formatDateTime(d, d.getFullYear() === Time.date.getFullYear() ? "ddd d MMM" : "ddd d MMM yyyy");
    }

    // When an event happens on the day `d`: "All day", "14:00 – 15:00", "Day 2 of 3"
    function timeLabel(ev: var, d: date): string {
        const span = spanOf(ev, d);
        if (span) {
            const n = span[0];
            const of = span[1];
            if (!ev.allDay && n === 1)
                return Tr.tr("From %1").arg(formatTime(ev.start));
            if (!ev.allDay && n === of)
                return Tr.tr("Until %1").arg(formatTime(ev.end));
            return Tr.tr("Day %1 of %2").arg(n).arg(of);
        }
        if (ev.allDay)
            return Tr.tr("All day");
        if (ev.end.getTime() <= ev.start.getTime())
            return formatTime(ev.start);
        return `${formatTime(ev.start)} – ${formatTime(ev.end)}`;
    }

    // How far off an event is, for a countdown: "Now", "in 25 min", "in 3 h", "Tomorrow"
    function relativeLabel(ev: var): string {
        if (isOngoing(ev))
            return Tr.tr("Now");
        if (ev.allDay)
            return dayDiff(ev.start) <= 0 ? Tr.tr("Today") : dayLabel(ev.start);

        const minutes = Math.round((ev.start.getTime() - Time.date.getTime()) / 60000);
        // Already over: a countdown would read backwards, so say when it was instead
        if (minutes < 0)
            return timeLabel(ev, ev.start);
        if (minutes < 60)
            return Tr.tr("in %1 min").arg(Math.max(1, minutes));
        if (minutes < 12 * 60 && dayDiff(ev.start) === 0)
            return Tr.tr("in %1 h").arg(Math.round(minutes / 60));
        return dayLabel(ev.start);
    }

    // A span of time as "25 min", "2 h" or "1 h 30 min"
    function durationLabel(ms: real): string {
        const minutes = Math.max(1, Math.round(ms / 60000));
        if (minutes < 60)
            return Tr.tr("%1 min").arg(minutes);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return m === 0 ? Tr.tr("%1 h").arg(h) : Tr.tr("%1 h %2 min").arg(h).arg(m);
    }

    // Upcoming events grouped by the day they fall on (an event under way since before today
    // goes under today), as [{ day: Date, events: [...] }], at most `limit` events in all
    function grouped(limit: int): var {
        const now = Time.date;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const groups = [];
        for (const ev of upcoming.slice(0, limit)) {
            const start = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate());
            const day = start < today ? today : start;
            const last = groups[groups.length - 1];
            if (last && sameDay(last.day, day))
                last.events.push(ev);
            else
                groups.push({
                    day,
                    events: [ev]
                });
        }
        return groups;
    }

    function openDate(d: date): void {
        Quickshell.execDetached(["gnome-calendar", "--date", key(d)]);
    }

    function openApp(): void {
        Quickshell.execDetached(["gnome-calendar"]);
    }

    // GNOME Calendar names an event "<calendar>:<uid>" and an occurrence of a recurring one
    // "<calendar>:<uid>:<recurrence id>", the same ids its shell search provider hands out
    function openEvent(ev: var): void {
        const id = ev.rid ? `${ev.calendar}:${ev.uid}:${ev.rid}` : `${ev.calendar}:${ev.uid}`;
        Quickshell.execDetached(["gnome-calendar", "--uuid", id]);
    }

    function parseDate(v: var): date {
        if (typeof v === "string") {
            const [y, m, d] = v.split("-").map(Number);
            return new Date(y, m - 1, d);
        }
        return new Date(v * 1000);
    }

    function apply(msg: var): void {
        lastMessage = msg;

        const cals = {};
        for (const c of msg.calendars)
            cals[c.uid] = {
                name: c.name,
                colour: c.colour,
                backend: c.backend ?? ""
            };

        const list = msg.events.map(e => ({
                    uid: e.uid,
                    rid: e.rid,
                    calendar: e.calendar,
                    summary: e.summary,
                    location: e.location,
                    allDay: e.allDay,
                    start: parseDate(e.start),
                    end: parseDate(e.end),
                    freq: e.freq ?? "",
                    kind: kindOf(e, cals[e.calendar]),
                    colour: cals[e.calendar]?.colour ?? "",
                    calendarName: cals[e.calendar]?.name ?? ""
                }));
        list.sort((a, b) => a.start - b.start || b.allDay - a.allDay || a.summary.localeCompare(b.summary));

        const days = {};
        for (const ev of list) {
            const last = lastDay(ev);
            for (let d = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate()); d <= last; d.setDate(d.getDate() + 1)) {
                const k = key(d);
                if (!days[k])
                    days[k] = [];
                days[k].push(ev);
            }
        }
        // All-day and multi-day events lead the day, the way GNOME Calendar stacks them
        for (const k in days)
            days[k].sort((a, b) => (b.allDay || dayCount(b) > 1) - (a.allDay || dayCount(a) > 1) || a.start - b.start);

        calendars = cals;
        events = list;
        byDay = days;
        loaded = true;
    }

    function send(): void {
        if (proc.running)
            proc.write(`range ${range}\n`);
    }

    onRangeChanged: send()

    onKindOverridesChanged: {
        if (lastMessage)
            apply(lastMessage);
    }

    onWantedChanged: {
        if (wanted) {
            proc.running = true;
        } else {
            restartTimer.stop();
            proc.running = false;
        }
    }

    Process {
        id: proc

        command: ["python3", Quickshell.shellPath("scripts/caelestia-calendar.py")]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }

                if (msg.type === "events")
                    root.apply(msg);
                else if (msg.type === "error" && msg.fatal)
                    root.available = false;
                else if (msg.type === "error")
                    console.warn("calendar:", msg.message);
            }
        }

        onStarted: root.send()

        onExited: code => {
            // 2 is the helper saying evolution-data-server is not installed: nothing to retry
            if (code === 2) {
                root.available = false;
                return;
            }
            if (root.wanted)
                restartTimer.restart();
        }
    }

    // The helper only stops on its own when evolution-data-server goes away under it (an
    // update restarting the daemon, say), so bring it back once things have settled
    Timer {
        id: restartTimer

        interval: 5000
        onTriggered: {
            if (root.wanted)
                proc.running = true;
        }
    }
}
