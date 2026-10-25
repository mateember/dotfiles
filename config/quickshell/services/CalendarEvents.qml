pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Calendar events (Nextcloud CalDAV, Google, Neptun, ... whatever GNOME Calendar set up) from
// Evolution Data Server, via `hcs-calendar-events FROM TO` (~/Nix calendar-events.nix, which runs
// scripts/calendar-events.py). The JSON is cached in Quickshell's cache dir, so the last known
// events show immediately at startup and offline. EDS syncs the accounts itself; no passwords here.
Singleton {
    id: root

    property bool ready: false
    property bool stale: false            // last run failed; showing cached data
    property var events: []               // [{ calendar, color, kind, title, location, start: Date, end: Date, allday }]
    property var byDay: ({})              // "yyyy-MM-dd" → [event] (multi-day events in every day they touch)
    property string rangeFrom: ""         // range of the loaded data (yyyy-MM-dd, `to` exclusive)
    property string rangeTo: ""

    // The month the popup shows (set by Clock.qml); the fetched range covers it plus today + 30 days.
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property string cacheFile: Quickshell.cachePath("calendar-events.json")

    // Current or next timed event (or task due) from now, within the loaded range.
    readonly property var nextUp: {
        const now = Time.date;
        for (const e of root.events)
            if (!e.allday && e.end > now) return e;
        return null;
    }

    function pad(n: int): string { return n < 10 ? "0" + n : "" + n; }
    function key(d: date): string { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }

    // "2026-10-27T08:15:00" / "2026-10-27" → local Date (never UTC).
    function parseLocal(s: string): date {
        const n = s.split(/[-T:]/).map(Number);
        return new Date(n[0], n[1] - 1, n[2], n[3] || 0, n[4] || 0, n[5] || 0);
    }

    function eventsOn(d: date): var { return root.byDay[key(d)] ?? []; }

    function visible(e: var): bool {
        if (Config.calendarHidden.indexOf(e.calendar) >= 0) return false;
        return Config.calendarShowTasks || e.kind !== "task";
    }

    function parse(text: string) {
        try {
            const j = JSON.parse(text);
            const evs = [], days = {};
            for (const r of j.events) {
                if (!root.visible(r)) continue;
                const e = {
                    calendar: r.calendar, color: r.color, kind: r.kind, title: r.title || "(no title)",
                    location: r.location, allday: r.allday,
                    start: root.parseLocal(r.start), end: root.parseLocal(r.end)
                };
                evs.push(e);
                // Days touched: [start, end) for all-day, [start, end] for timed (a 0-length task counts once).
                const d = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate());
                const last = e.allday ? new Date(e.end.getTime() - 1) : (e.end > e.start ? new Date(e.end.getTime() - 1) : e.start);
                for (let i = 0; i < 62 && d <= last; i++, d.setDate(d.getDate() + 1))
                    (days[root.key(d)] = days[root.key(d)] ?? []).push(e);
                if (e.allday && e.end <= e.start) (days[root.key(e.start)] = days[root.key(e.start)] ?? []).push(e);
            }
            evs.sort((a, b) => a.start - b.start);
            root.events = evs;
            root.byDay = days;
            root.rangeFrom = j.from;
            root.rangeTo = j.to;
            root.ready = true;
        } catch (err) {
            console.warn("CalendarEvents: could not parse cache:", err);
        }
    }

    // Range for the viewed month (with the grid's leading/trailing days) and the next 30 days.
    function wantedRange(): var {
        const today = new Date();
        const a = new Date(root.viewYear, root.viewMonth, 1 - 7);
        const b = new Date(root.viewYear, root.viewMonth + 1, 1 + 14);
        const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const t1 = new Date(t0.getTime()); t1.setDate(t1.getDate() + 31);
        return [key(a < t0 ? a : t0), key(b > t1 ? b : t1)];
    }

    function refresh() {
        const r = wantedRange();
        if (fetch.running) { pending = true; return; }
        fetch.from = r[0];
        fetch.to = r[1];
        fetch.running = true;
    }
    property bool pending: false

    onViewMonthChanged: refresh()
    onViewYearChanged: refresh()

    FileView {
        id: cache
        path: root.cacheFile
        printErrors: false
        onLoaded: root.parse(text())
    }

    // Writes to a temp file and renames, so a failed run never clobbers the cache.
    Process {
        id: fetch
        property string from: ""
        property string to: ""
        command: ["sh", "-c", `
            cache=$1; shift
            mkdir -p "$(dirname "$cache")"
            timeout 60 hcs-calendar-events "$@" > "$cache.tmp" && mv "$cache.tmp" "$cache"`,
            "sh", root.cacheFile, from, to].concat(Config.calendarShowTasks ? [] : ["--no-tasks"])
        onExited: code => {
            root.stale = code !== 0;
            if (code === 0) cache.reload();
            if (root.pending) { root.pending = false; root.refresh(); }
        }
    }

    Timer {
        interval: Config.calendarRefreshMinutes * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Re-parse when the calendar filters change (hot reload of Config.qml).
    Connections {
        target: Config
        function onCalendarHiddenChanged() { cache.reload(); }
        function onCalendarShowTasksChanged() { root.refresh(); }
    }
}
