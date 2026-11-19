#!/usr/bin/env python3
"""Streams the user's calendar events to the shell, as JSON lines on stdout.

Reads through evolution-data-server, the store GNOME Calendar keeps its calendars in, so
everything it shows comes across: local calendars, online accounts (Google, Nextcloud,
CalDAV), the contacts' birthdays, and recurring events expanded into their occurrences.
Only the calendars ticked in GNOME Calendar's sidebar are read, so the dashboard shows the
same set the app does.

stdin takes one command per line:
    range YYYY-MM-DD YYYY-MM-DD   watch these local dates, both inclusive
    refresh                       read everything again now

stdout gets one line per change:
    {"type": "events", "from": ..., "to": ..., "calendars": [...], "events": [...]}
    {"type": "error", "message": ...}

Each event carries "freq", how often it repeats ("daily", "weekly", "monthly", "yearly", or
"" for a one-off), which is what the shell sorts events into regular, special and rare by, and
each calendar its "backend" ("contacts" being the birthdays). An event's start and end are either "YYYY-MM-DD" (all-day; the end is exclusive, as in
iCalendar) or seconds since the epoch.
"""

from __future__ import annotations

import json
import sys
from datetime import date, datetime, timedelta

try:
    import gi

    gi.require_version("EDataServer", "1.2")
    gi.require_version("ECal", "2.0")
    from gi.repository import ECal, EDataServer, GLib  # noqa: E402

    # ECal pulls in whichever libical-glib it was built against; name it so gi does not warn
    for version in ("4.0", "3.0"):
        try:
            gi.require_version("ICalGLib", version)
            break
        except ValueError:
            pass
    from gi.repository import ICalGLib  # noqa: E402
except (ImportError, ValueError) as e:
    print(json.dumps({"type": "error", "fatal": True, "message": f"evolution-data-server is not available: {e}"}), flush=True)
    sys.exit(2)

# Coalesces bursts of view signals (a sync can touch hundreds of objects) into one read
DEBOUNCE_MS = 250
CONNECT_TIMEOUT_S = 10


def emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def local_epoch(d: date) -> int:
    return int(datetime(d.year, d.month, d.day).timestamp())


FREQUENCIES = {
    ICalGLib.RecurrenceFrequency.SECONDLY_RECURRENCE: "secondly",
    ICalGLib.RecurrenceFrequency.MINUTELY_RECURRENCE: "minutely",
    ICalGLib.RecurrenceFrequency.HOURLY_RECURRENCE: "hourly",
    ICalGLib.RecurrenceFrequency.DAILY_RECURRENCE: "daily",
    ICalGLib.RecurrenceFrequency.WEEKLY_RECURRENCE: "weekly",
    ICalGLib.RecurrenceFrequency.MONTHLY_RECURRENCE: "monthly",
    ICalGLib.RecurrenceFrequency.YEARLY_RECURRENCE: "yearly",
}


def recurrence_of(comp) -> str:
    """How often an event repeats ("weekly", "yearly", ...), or "" for a one-off."""
    prop = comp.get_first_property(ICalGLib.PropertyKind.RRULE_PROPERTY)
    if prop is None:
        return ""
    return FREQUENCIES.get(prop.get_rrule().get_freq(), "")


class Calendars:
    def __init__(self) -> None:
        self.registry = EDataServer.SourceRegistry.new_sync(None)
        self.clients: dict[str, ECal.Client] = {}
        self.views: dict[str, ECal.ClientView] = {}
        self.connecting: set[str] = set()
        self.pending = 0
        self.default_zone = ECal.util_get_system_timezone() or ICalGLib.Timezone.get_utc_timezone()

        today = date.today()
        self.start = today.replace(day=1) - timedelta(days=7)
        self.end = (today.replace(day=28) + timedelta(days=40)).replace(day=1) + timedelta(days=6)

        for signal in ("source-added", "source-removed", "source-changed", "source-enabled", "source-disabled"):
            self.registry.connect(signal, lambda *_: self.sync_sources())

        self.sync_sources()

    # ---- sources -------------------------------------------------------------------------

    def wanted_sources(self) -> list:
        out = []
        for source in self.registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR):
            ext = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
            # GNOME Calendar hides a calendar by unticking it, which clears "selected"
            if ext.get_selected():
                out.append(source)
        return out

    def sync_sources(self) -> None:
        wanted = {s.get_uid(): s for s in self.wanted_sources()}

        for uid in list(self.clients):
            if uid not in wanted:
                self.drop(uid)

        for uid, source in wanted.items():
            if uid not in self.clients and uid not in self.connecting:
                self.open(source)

        self.schedule()

    def open(self, source) -> None:
        uid = source.get_uid()
        self.connecting.add(uid)

        # Asynchronous, so a slow calendar (an online account, or the factory starting up on
        # first use) does not hold back the ones that are ready
        def done(_obj, result, *_):
            self.connecting.discard(uid)
            try:
                client = ECal.Client.connect_finish(result)
            except GLib.Error as e:
                emit({"type": "error", "message": f"{source.get_display_name()}: {e.message}"})
                return
            # Unticked or removed while the connection was on its way
            if uid not in {s.get_uid() for s in self.wanted_sources()}:
                return
            self.clients[uid] = client
            self.watch(uid)
            self.schedule()

        ECal.Client.connect(source, ECal.ClientSourceType.EVENTS, CONNECT_TIMEOUT_S, None, done, None)

    def drop(self, uid: str) -> None:
        view = self.views.pop(uid, None)
        if view is not None:
            try:
                view.stop()
            except GLib.Error:
                pass
        self.clients.pop(uid, None)

    # ---- live updates --------------------------------------------------------------------

    def sexp(self) -> str:
        start = ECal.isodate_from_time_t(local_epoch(self.start))
        end = ECal.isodate_from_time_t(local_epoch(self.end + timedelta(days=1)))
        return f'(occur-in-time-range? (make-time "{start}") (make-time "{end}"))'

    def watch(self, uid: str) -> None:
        old = self.views.pop(uid, None)
        if old is not None:
            try:
                old.stop()
            except GLib.Error:
                pass

        client = self.clients[uid]
        try:
            ok, view = client.get_view_sync(self.sexp(), None)
        except GLib.Error as e:
            emit({"type": "error", "message": f"{uid}: {e.message}"})
            return
        if not ok or view is None:
            return

        for signal in ("objects-added", "objects-modified", "objects-removed"):
            view.connect(signal, lambda *_: self.schedule())
        view.start()
        self.views[uid] = view

    def set_range(self, start: date, end: date) -> None:
        if end < start:
            start, end = end, start
        if (start, end) == (self.start, self.end):
            return
        self.start, self.end = start, end
        for uid in list(self.clients):
            self.watch(uid)
        self.schedule()

    def schedule(self) -> None:
        if self.pending:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(DEBOUNCE_MS, self.flush)

    # ---- reading -------------------------------------------------------------------------

    def to_value(self, t) -> tuple[str | int, bool]:
        if t.is_date():
            return f"{t.get_year():04d}-{t.get_month():02d}-{t.get_day():02d}", True
        zone = t.get_timezone() or self.default_zone
        return int(t.as_timet_with_zone(zone)), False

    def read(self, uid: str, client) -> list:
        source = self.registry.ref_source(uid)
        name = source.get_display_name() if source else uid
        events = []

        # A moved or edited occurrence of a recurring event comes back without its series' rule,
        # so it borrows the frequency from its siblings once they have all been read
        freq_by_uid: dict[str, str] = {}

        def on_instance(comp, inst_start, inst_end, *_):
            try:
                start, all_day = self.to_value(inst_start)
                end, _ = self.to_value(inst_end) if inst_end else (start, all_day)
                rid = comp.get_recurrenceid()
                freq = recurrence_of(comp)
                if freq:
                    freq_by_uid[comp.get_uid() or ""] = freq
                events.append({
                    "freq": freq,
                    "uid": comp.get_uid() or "",
                    "rid": rid.as_ical_string() if rid and not rid.is_null_time() else "",
                    "calendar": uid,
                    "summary": comp.get_summary() or "",
                    "location": comp.get_location() or "",
                    "start": start,
                    "end": end,
                    "allDay": all_day,
                })
            except Exception as e:  # one malformed event must not hide the rest
                emit({"type": "error", "message": f"{name}: {e}"})
            return True

        client.generate_instances_sync(
            local_epoch(self.start), local_epoch(self.end + timedelta(days=1)), None, on_instance
        )
        for ev in events:
            if not ev["freq"] and ev["rid"]:
                ev["freq"] = freq_by_uid.get(ev["uid"], "weekly")
        return events

    def flush(self) -> bool:
        self.pending = 0
        calendars, events = [], []

        for uid, client in self.clients.items():
            source = self.registry.ref_source(uid)
            if source is None:
                continue
            ext = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
            calendars.append({
                "uid": uid,
                "name": source.get_display_name(),
                "colour": ext.get_color() or "",
                # "contacts" is the birthdays and anniversaries calendar
                "backend": ext.get_backend_name() or "",
            })
            try:
                events.extend(self.read(uid, client))
            except GLib.Error as e:
                emit({"type": "error", "message": f"{source.get_display_name()}: {e.message}"})

        emit({
            "type": "events",
            "from": self.start.isoformat(),
            "to": self.end.isoformat(),
            "calendars": calendars,
            "events": events,
        })
        return GLib.SOURCE_REMOVE


def main() -> None:
    loop = GLib.MainLoop()
    try:
        cals = Calendars()
    except GLib.Error as e:
        emit({"type": "error", "fatal": True, "message": e.message})
        sys.exit(1)

    def on_stdin(channel, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            loop.quit()
            return False
        line = channel.readline()
        if not line:
            loop.quit()
            return False

        parts = line.split()
        if parts[:1] == ["range"] and len(parts) == 3:
            try:
                cals.set_range(date.fromisoformat(parts[1]), date.fromisoformat(parts[2]))
            except ValueError:
                emit({"type": "error", "message": f"bad range: {line.strip()}"})
        elif parts[:1] == ["refresh"]:
            cals.sync_sources()
        return True

    channel = GLib.IOChannel.unix_new(sys.stdin.fileno())
    GLib.io_add_watch(channel, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    loop.run()


if __name__ == "__main__":
    main()
