pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Central state and navigation router for the native HCS Settings application.
// Supports deep-linking (`SettingsState.openPage("network")`), back/forward history,
// cross-page search, and IPC (`qs ipc call settings ...`).
Singleton {
    id: root

    property bool open: false
    property string activePage: "network"
    property string activeSubTab: ""
    property string searchQuery: ""

    // In-app navigation history: [{ page, subTab }]
    property var navHistory: [{ page: "network", subTab: "" }]
    property int navIndex: 0

    readonly property bool canGoBack: navIndex > 0
    readonly property bool canGoForward: navIndex >= 0 && navIndex < navHistory.length - 1

    readonly property var categories: [
        { id: "connectivity",    label: "Connectivity" },
        { id: "personalization", label: "Personalization" },
        { id: "hardware",        label: "Hardware" },
        { id: "desktop",         label: "Desktop & Apps" },
        { id: "system",          label: "System" }
    ]

    readonly property var pages: [
        // Connectivity
        {
            id: "network",
            category: "connectivity",
            title: "Network & VPN",
            subtitle: "Wi-Fi, Ethernet, VPN profiles & Tailscale",
            icon: "wifi",
            keywords: ["wifi", "wi-fi", "wlan", "ethernet", "lan", "vpn", "wireguard", "tailscale", "exit node", "ip", "dns", "mac", "hidden network", "saved networks", "internet"]
        },
        {
            id: "bluetooth",
            category: "connectivity",
            title: "Bluetooth",
            subtitle: "Paired devices, discovery & battery",
            icon: "bluetooth",
            keywords: ["bluetooth", "bt", "headphones", "audio", "pair", "scan", "discoverable", "mouse", "keyboard", "speaker"]
        },
        {
            id: "phone",
            category: "connectivity",
            title: "Phone & Continuity",
            subtitle: "KDE Connect battery, ring & sharing",
            icon: "smartphone",
            keywords: ["phone", "kdeconnect", "kde connect", "android", "ring", "ping", "clipboard", "share", "continuity"]
        },

        // Personalization
        {
            id: "appearance",
            category: "personalization",
            title: "Appearance & Theme",
            subtitle: "Profiles, colors, opacity & desktop sync",
            icon: "palette",
            keywords: ["theme", "profile", "colors", "accent", "opacity", "transparency", "glass", "font", "typography", "radius", "dark", "light", "gtk", "qt", "kvantum", "wallpaper accent", "sync", "animation"]
        },
        {
            id: "background",
            category: "personalization",
            title: "Background",
            subtitle: "Slideshows, images, shaders, video & effects",
            icon: "photo_library",
            keywords: ["wallpaper", "background", "slideshow", "bing", "shader", "animated", "video", "snow", "blur", "dim", "solid", "ken burns"]
        },
        {
            id: "panel",
            category: "personalization",
            title: "Top Bar",
            subtitle: "Toggle, reorder & position bar widgets",
            icon: "view_agenda",
            keywords: ["bar", "panel", "widgets", "modules", "order", "left", "center", "right", "tray", "workspaces"]
        },

        // Hardware
        {
            id: "displays",
            category: "hardware",
            title: "Displays & Night Light",
            subtitle: "Monitor layout, Hz, scale, brightness & warmth",
            icon: "desktop_windows",
            keywords: ["display", "monitor", "screen", "arrangement", "resolution", "refresh rate", "hz", "120", "60", "scale", "vrr", "brightness", "ddc", "keyboard backlight", "night light", "hyprsunset", "warmth", "schedule", "sunshine", "virtual", "headless", "mirror", "extend"]
        },
        {
            id: "sound",
            category: "hardware",
            title: "Sound & Feedback",
            subtitle: "Output, input, app mixer & UI sound cues",
            icon: "volume_up",
            keywords: ["sound", "audio", "volume", "speaker", "microphone", "mic", "mute", "pipewire", "mixer", "applications", "over-amplification", "cues", "chime", "test"]
        },
        {
            id: "power",
            category: "hardware",
            title: "Power & Battery",
            subtitle: "TLP profile, conservation mode & caffeine",
            icon: "battery_full",
            keywords: ["battery", "power", "tlp", "saver", "balanced", "performance", "conservation", "ideapad", "charge limit", "caffeine", "awake", "sleep", "idle"]
        },

        // Desktop & Apps
        {
            id: "desktop",
            category: "desktop",
            title: "Desktop & Windowing",
            subtitle: "Hyprland layout, gaps, borders, blur & motion",
            icon: "view_column",
            keywords: ["hyprland", "layout", "scrolling", "dwindle", "master", "monocle", "gaps", "borders", "rounding", "blur", "opacity", "animations", "tiling"]
        },
        {
            id: "input",
            category: "desktop",
            title: "Input & Keybindings",
            subtitle: "Touchpad, mouse, keyboard layouts & shortcuts",
            icon: "keyboard",
            keywords: ["input", "mouse", "touchpad", "sensitivity", "natural scroll", "accel", "flat", "keyboard", "layout", "hu", "us", "en", "caps lock", "keybinds", "shortcuts", "cheatsheet"]
        },
        {
            id: "notifications",
            category: "desktop",
            title: "Notifications & Privacy",
            subtitle: "Do Not Disturb, auto-DND, app mutes & sensors",
            icon: "notifications",
            keywords: ["notifications", "dnd", "do not disturb", "fullscreen", "screenshare", "mute", "privacy", "camera", "microphone", "toast", "history"]
        },
        {
            id: "weather",
            category: "desktop",
            title: "Weather, Date & Time",
            subtitle: "Forecast sources, units, clock & calendar",
            icon: "partly_cloudy_day",
            keywords: ["weather", "hungaromet", "open-meteo", "forecast", "location", "units", "clock", "date", "time", "timezone", "ntp", "calendar", "24h", "12h"]
        },
        {
            id: "apps",
            category: "desktop",
            title: "Apps, Autostart & Services",
            subtitle: "Default apps, startup entries & systemd units",
            icon: "apps",
            keywords: ["apps", "default", "browser", "terminal", "files", "xdg-mime", "autostart", "startup", "systemd", "services", "hypridle", "pipewire", "portal"]
        },

        // System
        {
            id: "lock",
            category: "system",
            title: "Lock Screen & Security",
            subtitle: "Howdy face unlock, lock widgets & idle timers",
            icon: "lock",
            keywords: ["lock", "security", "howdy", "face", "pam", "avatar", "greeting", "hypridle", "suspend", "dpms", "caps"]
        },
        {
            id: "about",
            category: "system",
            title: "About & System",
            subtitle: "Hardware info, NixOS, drives & shell tools",
            icon: "info",
            keywords: ["about", "system", "nixos", "kernel", "cpu", "gpu", "ram", "disk", "hostname", "usb", "drives", "storage", "restart", "reload", "logs"]
        }
    ]

    function pageById(id: string): var {
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].id === id) return pages[i];
        }
        return pages[0];
    }

    function normalizePageId(id: string): string {
        const s = (id || "").trim().toLowerCase();
        if (!s) return root.activePage || "network";
        const aliases = {
            "wifi": "network",
            "vpn": "network",
            "bt": "bluetooth",
            "kdeconnect": "phone",
            "theme": "appearance",
            "themes": "appearance",
            "opacity": "appearance",
            "colors": "appearance",
            "wallpaper": "background",
            "bar": "panel",
            "barsettings": "panel",
            "display": "displays",
            "monitor": "displays",
            "monitors": "displays",
            "nightlight": "displays",
            "audio": "sound",
            "volume": "sound",
            "battery": "power",
            "caffeine": "power",
            "hyprland": "desktop",
            "layout": "desktop",
            "keybinds": "input",
            "shortcuts": "input",
            "keyboard": "input",
            "mouse": "input",
            "touchpad": "input",
            "privacy": "notifications",
            "dnd": "notifications",
            "clock": "weather",
            "calendar": "weather",
            "datetime": "weather",
            "date-time": "weather",
            "time": "weather",
            "services": "apps",
            "autostart": "apps",
            "defaultapps": "apps",
            "security": "lock",
            "howdy": "lock",
            "users": "lock",
            "system": "about",
            "storage": "about",
            "drives": "about"
        };
        const target = aliases[s] || s;
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].id === target) return target;
        }
        return "network";
    }

    function openPage(pageId: string, subTab: string) {
        const norm = normalizePageId(pageId);
        const sub = (subTab !== undefined && subTab !== null) ? String(subTab) : "";
        const changed = (norm !== root.activePage || sub !== root.activeSubTab);
        if (changed) {
            const sliced = root.navHistory.slice(0, root.navIndex + 1);
            sliced.push({ page: norm, subTab: sub });
            root.navHistory = sliced.slice(-30);
            root.navIndex = root.navHistory.length - 1;
            root.activePage = norm;
            root.activeSubTab = sub;
        }
        root.open = true;
    }

    function selectPage(pageId: string, subTab: string) {
        openPage(pageId, subTab === undefined ? "" : subTab);
    }

    function goBack() {
        if (!root.canGoBack) return;
        root.navIndex = root.navIndex - 1;
        const entry = root.navHistory[root.navIndex];
        if (entry) {
            root.activePage = entry.page;
            root.activeSubTab = entry.subTab || "";
        }
    }

    function goForward() {
        if (!root.canGoForward) return;
        root.navIndex = root.navIndex + 1;
        const entry = root.navHistory[root.navIndex];
        if (entry) {
            root.activePage = entry.page;
            root.activeSubTab = entry.subTab || "";
        }
    }

    function stepPage(delta: int) {
        const idx = pages.findIndex(p => p.id === root.activePage);
        const next = ((idx + delta) % pages.length + pages.length) % pages.length;
        selectPage(pages[next].id, "");
    }

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open = true; }
        function close(): void { root.close(); }
        function page(id: string): void { root.openPage(id, ""); }
        function subpage(id: string, sub: string): void { root.openPage(id, sub); }
    }
}
