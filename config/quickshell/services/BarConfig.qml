pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent configuration for bar modules: which ones are enabled, their section
// ("left", "center", "right"), and their order within each section.
// Stored in Quickshell's state dir (bar-config.json) so changes survive restarts.
Singleton {
    id: root

    // Whether the Bar Settings window (bar/BarSettingsWindow.qml) is open.
    property bool settingsOpen: false

    readonly property string stateFile: Quickshell.statePath("bar-config.json")

    readonly property var defaultItems: [
        // Left
        { id: "workspaces",    name: "Workspaces",           subtitle: "Workspace indicators on this monitor",     icon: "workspaces",          section: "left",   enabled: true },
        { id: "clipboard",     name: "Clipboard",            subtitle: "Clipboard history (cliphist)",             icon: "content_paste",       section: "left",   enabled: true },
        { id: "nightlight",    name: "Night Light",          subtitle: "Screen warmth control (hyprsunset)",       icon: "nightlight",          section: "left",   enabled: true },
        { id: "caffeine",      name: "Caffeine",             subtitle: "Keep screen awake",                        icon: "coffee",              section: "left",   enabled: true },
        { id: "stats",         name: "System Stats",         subtitle: "CPU load, temperature and RAM usage",      icon: "memory",              section: "left",   enabled: true },
        // Center
        { id: "weather",       name: "Weather",              subtitle: "Current conditions and 5-day forecast",    icon: "partly_cloudy_day",   section: "center", enabled: true },
        { id: "clock",         name: "Clock & Calendar",     subtitle: "Date, time and calendar events",           icon: "calendar_month",      section: "center", enabled: true },
        // Right
        { id: "tray",          name: "System Tray",          subtitle: "Background app tray icons",                icon: "dock_to_bottom",      section: "right",  enabled: true },
        { id: "display",       name: "Display & Brightness", subtitle: "Brightness, keyboard light, screenshots",  icon: "desktop_windows",     section: "right",  enabled: true },
        { id: "layout",        name: "Tiling Layout",        subtitle: "Scrolling / dwindle layout switch",        icon: "view_column",         section: "right",  enabled: true },
        { id: "media",         name: "Media Player",         subtitle: "Now playing and MPRIS controls",           icon: "play_arrow",          section: "right",  enabled: true },
        { id: "volume",        name: "Volume",               subtitle: "Output, input and app volume mixer",       icon: "volume_up",           section: "right",  enabled: true },
        { id: "bluetooth",     name: "Bluetooth",            subtitle: "Bluetooth toggle and device list",         icon: "bluetooth",           section: "right",  enabled: true },
        { id: "network",       name: "Network",              subtitle: "Wi-Fi and Ethernet connections",           icon: "wifi",                section: "right",  enabled: true },
        { id: "battery",       name: "Battery",              subtitle: "Battery status and TLP power mode",        icon: "battery_full",        section: "right",  enabled: true },
        { id: "notifications", name: "Notifications",        subtitle: "Notification center and Do Not Disturb",   icon: "notifications",       section: "right",  enabled: true },
        { id: "quicksettings", name: "Quick Settings",       subtitle: "Quick settings panel button",              icon: "tune",                section: "right",  enabled: true },
        { id: "power",         name: "Power Menu",           subtitle: "Lock, suspend, log out, reboot, poweroff", icon: "power_settings_new",  section: "right",  enabled: true }
    ]

    property var items: defaultItems.map(i => Object.assign({}, i))

    readonly property var leftIds: items.filter(i => i.section === "left").map(i => i.id)
    readonly property var centerIds: items.filter(i => i.section === "center").map(i => i.id)
    readonly property var rightIds: items.filter(i => i.section === "right").map(i => i.id)

    readonly property var enabledMap: {
        const m = {};
        for (const i of root.items) m[i.id] = i.enabled;
        return m;
    }

    function isEnabled(id: string): bool {
        return root.enabledMap[id] ?? true;
    }

    function save() {
        const data = root.items.map(i => ({ id: i.id, section: i.section, enabled: i.enabled }));
        store.setText(JSON.stringify(data));
    }

    function toggle(id: string) {
        root.items = root.items.map(i => i.id === id ? Object.assign({}, i, { enabled: !i.enabled }) : i);
        save();
    }

    function setEnabled(id: string, val: bool) {
        root.items = root.items.map(i => i.id === id ? Object.assign({}, i, { enabled: val }) : i);
        save();
    }

    // Move item `id` up (-1) or down (+1) within its current section.
    function move(id: string, delta: int) {
        const list = root.items.slice();
        const idx = list.findIndex(i => i.id === id);
        if (idx < 0) return;
        const sec = list[idx].section;
        const secIndices = [];
        for (let k = 0; k < list.length; k++)
            if (list[k].section === sec) secIndices.push(k);
        const posInSec = secIndices.indexOf(idx);
        const targetPos = posInSec + delta;
        if (targetPos < 0 || targetPos >= secIndices.length) return;
        const swapIdx = secIndices[targetPos];
        const tmp = list[idx];
        list[idx] = list[swapIdx];
        list[swapIdx] = tmp;
        root.items = list;
        save();
    }

    // Cycle or set an item's section ("left" -> "center" -> "right" -> "left").
    function setSection(id: string, sec: string) {
        if (sec !== "left" && sec !== "center" && sec !== "right") return;
        root.items = root.items.map(i => i.id === id ? Object.assign({}, i, { section: sec }) : i);
        save();
    }

    function cycleSection(id: string) {
        const item = root.items.find(i => i.id === id);
        if (!item) return;
        const next = item.section === "left" ? "center" : item.section === "center" ? "right" : "left";
        setSection(id, next);
    }

    function reset() {
        root.items = root.defaultItems.map(i => Object.assign({}, i));
        save();
    }

    FileView {
        id: store
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (!Array.isArray(saved)) return;
                const byId = {};
                for (const d of root.defaultItems) byId[d.id] = d;
                const seen = {};
                const merged = [];
                for (const s of saved) {
                    if (!s || !byId[s.id] || seen[s.id]) continue;
                    seen[s.id] = true;
                    const sec = (s.section === "left" || s.section === "center" || s.section === "right")
                                ? s.section : byId[s.id].section;
                    merged.push(Object.assign({}, byId[s.id], {
                        section: sec,
                        enabled: s.enabled !== undefined ? Boolean(s.enabled) : true
                    }));
                }
                for (const d of root.defaultItems) {
                    if (!seen[d.id]) merged.push(Object.assign({}, d));
                }
                root.items = merged;
            } catch (e) {}
        }
    }

    IpcHandler {
        target: "barsettings"
        function toggle(): void { root.settingsOpen = !root.settingsOpen; }
        function open(): void { root.settingsOpen = true; }
        function close(): void { root.settingsOpen = false; }
        function reset(): void { root.reset(); }
    }
}
