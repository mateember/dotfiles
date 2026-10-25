pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light, driven by hyprsunset (started by Hyprland, schedule in ~/.config/hypr/hyprsunset.conf).
// Modes:
//   "auto" – follow the hyprsunset schedule (default)
//   "on"   – warm screen at `temperature` until switched back
//   "off"  – no filter until switched back
// hyprsunset re-applies its schedule at every profile time, so a manual mode is re-applied
// when the scheduled profile changes.
Singleton {
    id: root

    readonly property string mode: persist.mode
    readonly property int temperature: persist.temperature       // K used for "on"
    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6000

    // From the current scheduled profile (`hyprctl hyprsunset profile`)
    property bool scheduleWarm: false
    property string profileTime: ""
    property int currentTemperature: 6000
    property bool available: false

    readonly property bool active: mode === "on" || (mode === "auto" && scheduleWarm)

    // Schedule from hyprsunset.conf, for display: [{ time, warm, temperature }]
    property var schedule: []
    readonly property string scheduleText: {
        const warm = schedule.find(p => p.warm), cool = schedule.find(p => !p.warm);
        return warm && cool ? `${warm.time}–${cool.time}` : "";
    }

    function setMode(m: string) {
        persist.mode = m;
        apply();
    }
    function toggle() {
        // Toggling from "auto" goes to the opposite of what the schedule does right now.
        setMode(root.active ? "off" : "on");
    }
    function setTemperature(k: int) {
        persist.temperature = Math.max(minTemperature, Math.min(maxTemperature, Math.round(k / 100) * 100));
        if (root.mode !== "on") persist.mode = "on";
        apply();
    }

    function apply() {
        if (root.mode === "auto") run(["hyprctl", "hyprsunset", "reset"]);
        else if (root.mode === "on") run(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
        else run(["hyprctl", "hyprsunset", "identity"]);
        refreshTimer.restart();
    }
    function run(cmd) { Quickshell.execDetached(cmd); }

    PersistentProperties {
        id: persist
        reloadableId: "hcs-nightlight"
        property string mode: "auto"
        property int temperature: 4500
    }

    // Current scheduled profile + live temperature
    Process {
        id: poll
        command: ["sh", "-c", "hyprctl hyprsunset profile && echo \"Current: $(hyprctl hyprsunset temperature)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const get = k => (text.match(new RegExp("^" + k + ":\\s*(.+)$", "m")) || [])[1]?.trim();
                if (!get("Time")) { root.available = false; retryTimer.restart(); return; }
                root.available = true;
                const time = get("Time");
                const warm = get("Identity") !== "true" && Number(get("Temperature")) < 6000;
                const changed = root.profileTime !== "" && time !== root.profileTime;
                root.profileTime = time;
                root.scheduleWarm = warm;
                root.currentTemperature = Number(get("Current")) || 6000;
                if (changed && root.mode !== "auto") root.apply();   // keep the manual choice
            }
        }
    }

    // Profiles from hyprsunset.conf (time + whether it warms the screen)
    FileView {
        path: (Quickshell.env("HOME") ?? "") + "/.config/hypr/hyprsunset.conf"
        printErrors: false
        onLoaded: {
            const out = [];
            for (const block of text().split(/profile\s*\{/).slice(1)) {
                const body = block.split("}")[0];
                const time = (body.match(/time\s*=\s*([\d:]+)/) || [])[1] ?? "";
                const temp = Number((body.match(/temperature\s*=\s*(\d+)/) || [])[1] ?? 6000);
                const identity = /identity\s*=\s*true/.test(body);
                out.push({ time: time.replace(/^(\d):/, "0$1:"), warm: !identity && temp < 6000, temperature: temp });
            }
            root.schedule = out;
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
