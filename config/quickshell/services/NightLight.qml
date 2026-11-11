pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light. hyprsunset (started by Hyprland) only applies the colour; the schedule lives
// here and is checked against the wall clock every few seconds. hyprsunset's own profile
// timers don't count time spent suspended, so a switch that was due during sleep was missed
// and the screen stayed warm after waking. Checking the clock here doesn't have that problem.
// Modes:
//   "auto" – follow the schedule below (default)
//   "on"   – warm screen at `temperature` until switched back
//   "off"  – no filter until switched back
Singleton {
    id: root

    // ---- Schedule for "auto" (local time, HH:MM; may wrap past midnight) ----
    readonly property string warmFrom: "20:00"
    readonly property string warmUntil: "08:30"
    readonly property int scheduleTemperature: 5500
    readonly property int scheduleGamma: 80          // percent

    readonly property string mode: persist.mode
    readonly property int temperature: persist.temperature       // K used for "on"
    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6000

    property bool scheduleWarm: false
    property int currentTemperature: 6000            // what hyprsunset reports
    property bool available: false

    readonly property bool active: mode === "on" || (mode === "auto" && scheduleWarm)
    readonly property string scheduleText: `${warmFrom}–${warmUntil}`

    // What hyprsunset should be showing right now.
    readonly property int targetTemperature: mode === "on" ? temperature
        : (mode === "auto" && scheduleWarm) ? scheduleTemperature
        : 6000
    readonly property int targetGamma: (mode === "auto" && scheduleWarm) ? scheduleGamma : 100
    onTargetTemperatureChanged: apply()
    onTargetGammaChanged: apply()

    function setMode(m: string) {
        persist.mode = m;
    }
    function toggle() {
        // Toggling from "auto" goes to the opposite of what the schedule does right now.
        setMode(root.active ? "off" : "on");
    }
    function setTemperature(k: int) {
        persist.temperature = Math.max(minTemperature, Math.min(maxTemperature, Math.round(k / 100) * 100));
        if (root.mode !== "on") persist.mode = "on";
    }

    function minutesOf(hhmm: string): int {
        const p = hhmm.split(":");
        return Number(p[0]) * 60 + Number(p[1] ?? 0);
    }
    function updateSchedule() {
        const d = new Date();
        const now = d.getHours() * 60 + d.getMinutes();
        const from = minutesOf(warmFrom), until = minutesOf(warmUntil);
        root.scheduleWarm = from <= until ? (now >= from && now < until) : (now >= from || now < until);
    }

    property double lastApplyMs: 0
    function apply() {
        root.lastApplyMs = Date.now();
        // `identity` alone leaves the reported temperature at the old value, so set 6000 first.
        const t = root.targetTemperature >= 6000 ? "hyprctl hyprsunset temperature 6000 >/dev/null; hyprctl hyprsunset identity"
                                                 : `hyprctl hyprsunset temperature ${root.targetTemperature}`;
        Quickshell.execDetached(["sh", "-c", `${t} >/dev/null; hyprctl hyprsunset gamma ${root.targetGamma} >/dev/null`]);
        refreshTimer.restart();
    }

    PersistentProperties {
        id: persist
        reloadableId: "hcs-nightlight"
        property string mode: "auto"
        property int temperature: 4500
    }

    // Live temperature from hyprsunset. Re-applies if it doesn't match (e.g. hyprsunset was
    // restarted), but not right after we just applied, so it can't loop.
    Process {
        id: poll
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Number(text.trim());
                if (!t) { root.available = false; retryTimer.restart(); return; }
                const wasAvailable = root.available;
                root.available = true;
                root.currentTemperature = t;
                if (!wasAvailable || (t !== root.targetTemperature && Date.now() - root.lastApplyMs > 5000))
                    root.apply();
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: poll.running = true
    }
    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: poll.running = true
    }
    // Clock check: cheap (no process), so it can run often; catches up within 10 s after wake.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateSchedule()
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    // qs ipc call nightlight toggle | auto | on | off
    IpcHandler {
        target: "nightlight"
        function toggle(): void { root.toggle(); }
        function auto(): void { root.setMode("auto"); }
        function on(): void { root.setMode("on"); }
        function off(): void { root.setMode("off"); }
    }
}
