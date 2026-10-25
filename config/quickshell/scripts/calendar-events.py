#!/usr/bin/env python3
"""Print calendar events (and tasks with a due date) from Evolution Data Server as JSON.

Usage: calendar-events.py FROM TO [--no-tasks] [--only NAME,NAME]
  FROM/TO are local dates (YYYY-MM-DD), TO is exclusive.
Output: {"generated": iso, "from": .., "to": .., "calendars": [{name, color, kind}],
         "events": [{calendar, color, kind, title, start, end, allday, location, uid}]}
start/end are local "YYYY-MM-DDTHH:MM:SS" (all-day: "YYYY-MM-DD", end exclusive).
Recurring events are expanded by EDS. Accounts are whatever GNOME Calendar / Online
Accounts set up; this script never sees passwords.
"""
import json
import sys
from datetime import date, datetime, timedelta

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib  # noqa: E402

# Seconds to wait for a backend to come online; (guint32)-1 = don't wait, read EDS's local cache
# (EDS keeps syncing in the background; waiting made every remote calendar cost the full timeout).
TIMEOUT = 0xFFFFFFFF


def local_zone():
    try:
        name = open("/etc/timezone").read().strip()
    except OSError:
        name = None
    if not name:
        import os
        try:
            name = os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1]
        except (OSError, IndexError):
            name = "UTC"
    return ICalGLib.Timezone.get_builtin_timezone(name) or ICalGLib.Timezone.get_utc_timezone()


ZONE = local_zone()


def fmt(t, zone_hint=None):
    """ICalGLib.Time -> (string, is_date) in local time."""
    if t is None or t.is_null_time():
        return None, False
    if t.is_date():
        return "%04d-%02d-%02d" % (t.get_year(), t.get_month(), t.get_day()), True
    t = t.clone()
    if t.get_timezone() is None and not t.is_utc() and zone_hint is not None:
        t.set_timezone(zone_hint)
    t.convert_to_zone_inplace(ZONE)
    return "%04d-%02d-%02dT%02d:%02d:%02d" % (
        t.get_year(), t.get_month(), t.get_day(), t.get_hour(), t.get_minute(), t.get_second()), False


def ical_date(d):
    t = ICalGLib.Time.new_null_time()
    t.set_date(d.year, d.month, d.day)
    t.set_time(0, 0, 0)
    t.set_timezone(ZONE)
    return t


def selected(source, ext_name):
    if not source.get_enabled():
        return False
    ext = source.get_extension(ext_name)
    return ext.get_selected() if hasattr(ext, "get_selected") else True


def color_of(source, ext_name):
    c = (source.get_extension(ext_name).get_color() or "").strip()
    if c.startswith("rgb"):  # webcal sources store "rgb(r,g,b)"; QML wants hex
        try:
            r, g, b = (int(float(x)) for x in c[c.index("(") + 1:c.index(")")].split(",")[:3])
            c = "#%02x%02x%02x" % (r, g, b)
        except ValueError:
            c = ""
    return c or "#888888"


def connect(source, kind):
    try:
        return ECal.Client.connect_sync(source, kind, TIMEOUT, None)
    except Exception as e:  # offline, auth missing, ...
        print("calendar-events: %s: %s" % (source.get_display_name(), e), file=sys.stderr)
        return None


def events_of(source, start, end, out):
    client = connect(source, ECal.ClientSourceType.EVENTS)
    if client is None:
        return False
    name = source.get_display_name()
    color = color_of(source, EDataServer.SOURCE_EXTENSION_CALENDAR)
    t0 = int(datetime.combine(start, datetime.min.time()).timestamp())
    t1 = int(datetime.combine(end, datetime.min.time()).timestamp())

    def cb(icomp, istart, iend, *_):
        comp = ECal.Component.new_from_icalcomponent(icomp.clone())
        if comp is None:
            return True
        s, allday = fmt(istart, ZONE)
        e, _ = fmt(iend, ZONE)
        summary = comp.get_summary()
        loc = comp.get_location()
        out.append({
            "calendar": name, "color": color, "kind": "event",
            "title": summary.get_value() if summary else "",
            "start": s, "end": e or s, "allday": allday,
            "location": loc or "", "uid": comp.get_uid() or "",
        })
        return True

    client.generate_instances_sync(t0, t1, None, cb)
    return True


def tasks_of(source, start, end, out):
    client = connect(source, ECal.ClientSourceType.TASKS)
    if client is None:
        return False
    name = source.get_display_name()
    color = color_of(source, EDataServer.SOURCE_EXTENSION_TASK_LIST)
    s0 = ECal.isodate_from_time_t(int(datetime.combine(start, datetime.min.time()).timestamp()))
    s1 = ECal.isodate_from_time_t(int(datetime.combine(end, datetime.min.time()).timestamp()))
    sexp = '(and (due-in-time-range? (make-time "%s") (make-time "%s")) (not (is-completed?)))' % (s0, s1)
    try:
        ok, comps = client.get_object_list_as_comps_sync(sexp, None)
    except Exception as e:
        print("calendar-events: %s: %s" % (name, e), file=sys.stderr)
        return True
    for comp in comps or []:
        due = comp.get_due()
        if due is None:
            continue
        s, allday = fmt(due.get_value(), ZONE)
        if s is None:
            continue
        summary = comp.get_summary()
        out.append({
            "calendar": name, "color": color, "kind": "task",
            "title": summary.get_value() if summary else "",
            "start": s, "end": s, "allday": allday,
            "location": comp.get_location() or "", "uid": comp.get_uid() or "",
        })
    return True


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    flags = [a for a in argv if a.startswith("--")]
    start = date.fromisoformat(args[0]) if args else date.today().replace(day=1)
    end = date.fromisoformat(args[1]) if len(args) > 1 else start + timedelta(days=42)
    with_tasks = "--no-tasks" not in flags
    only = None
    for f in flags:
        if f.startswith("--only="):
            only = {x.strip() for x in f[7:].split(",") if x.strip()}

    registry = EDataServer.SourceRegistry.new_sync(None)
    out, calendars = [], []
    kinds = [(EDataServer.SOURCE_EXTENSION_CALENDAR, "event", events_of)]
    if with_tasks:
        kinds.append((EDataServer.SOURCE_EXTENSION_TASK_LIST, "task", tasks_of))
    for ext, kind, fn in kinds:
        for source in registry.list_sources(ext):
            if not selected(source, ext):
                continue
            if only is not None and source.get_display_name() not in only:
                continue
            if fn(source, start, end, out):
                calendars.append({"name": source.get_display_name(),
                                  "color": color_of(source, ext), "kind": kind})
    out.sort(key=lambda e: (e["start"][:10], not e["allday"], e["start"], e["title"]))
    json.dump({"generated": datetime.now().isoformat(timespec="seconds"),
               "from": start.isoformat(), "to": end.isoformat(),
               "calendars": calendars, "events": out}, sys.stdout, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main(sys.argv[1:])
