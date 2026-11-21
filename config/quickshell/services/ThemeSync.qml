pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Synchronizes active ThemeConfig profile across the whole desktop:
// - Hyprland active/inactive borders & window rounding (via HyprSettings)
// - GTK color-scheme (prefer-dark / prefer-light via gsettings)
// - Qt6 / KDE / Kvantum palette (reusing existing make-cosmic-shell-theme.py)
// - Match Wallpaper Accent (dominant color sampled via offscreen QML Canvas in Wallpaper.qml)
Singleton {
    id: root

    readonly property string stateFile: Quickshell.statePath("theme-sync.json")

    property bool syncHyprland: false
    property bool syncGtk: false
    property bool syncQt: false
    property bool autoWallpaperAccent: false
    property bool syncing: false
    property string lastSyncStatus: ""

    // Wallpaper accent extraction coordination (consumed by primary Wallpaper.qml Canvas)
    property bool extractingAccent: false
    property string extractImageUrl: ""
    property string lastExtractedHex: ""

    function isLightColor(hex: string): bool {
        const c = Qt.color(hex || "#1B1B1B");
        const luma = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        return luma > 0.55;
    }

    function setSyncHyprland(v: bool) { root.syncHyprland = v; save(); if (v) applyHyprland(); }
    function setSyncGtk(v: bool) { root.syncGtk = v; save(); if (v) applyGtk(); }
    function setSyncQt(v: bool) { root.syncQt = v; save(); if (v) applyQt(); }
    function setAutoWallpaperAccent(v: bool) {
        root.autoWallpaperAccent = v;
        save();
        if (v) requestWallpaperAccent();
    }

    function applyHyprland() {
        const cur = ThemeConfig.current;
        if (!cur) return;
        const accent = String(cur.accent || "#FFAD00");
        const secondary = isLightColor(cur.bg) ? String(cur.text || "#18181B") : "#FFFFFF";
        const inactive = String(cur.bgDivider || "#595959");
        const rad = Math.max(0, Math.min(20, Math.round(Number(cur.radiusS ?? 8))));
        HyprSettings.applyThemeBorders(accent, secondary, inactive, rad);
    }

    function applyGtk() {
        const light = isLightColor(ThemeConfig.current?.bg || "#1B1B1B");
        Quickshell.execDetached([
            "gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", light ? "prefer-light" : "prefer-dark"
        ]);
    }

    function applyQt() {
        if (qtProc.running) return;
        root.syncing = true;
        qtProc.running = true;
    }

    function syncNow() {
        const ran = [];
        if (root.syncHyprland) { applyHyprland(); ran.push("Hyprland"); }
        if (root.syncGtk) { applyGtk(); ran.push("GTK"); }
        if (root.syncQt) { applyQt(); ran.push("Qt/KDE"); }
        if (ran.length > 0) {
            root.lastSyncStatus = "Synced " + ran.join(", ") + " at " + Qt.formatTime(new Date(), "HH:mm:ss");
        }
    }

    function forceSyncAll() {
        applyHyprland();
        applyGtk();
        applyQt();
        root.lastSyncStatus = "Synced Hyprland, GTK & Qt/KDE at " + Qt.formatTime(new Date(), "HH:mm:ss");
    }

    // Trigger dominant-color extraction from the current wallpaper via QML Canvas.
    function requestWallpaperAccent() {
        let url = "";
        if (Wallpapers.mode === "image") {
            url = Wallpapers.resolvedSingleImageUrl || "";
        } else if (Wallpapers.mode === "folder") {
            const screens = Quickshell.screens;
            const sn = screens.length > 0 ? screens[0].name : "";
            url = (sn && Wallpapers.screenUrls[sn]) || Wallpapers.current || "";
        } else if (Wallpapers.mode === "solid") {
            const col = String(Wallpapers.solidColor || "#FFAD00");
            finishAccentExtraction(col);
            return;
        } else if (Wallpapers.mode === "animated") {
            const pal = Wallpapers.activePalette();
            if (pal && pal.c1) {
                finishAccentExtraction(pal.c1);
                return;
            }
        }
        if (!url) {
            root.lastSyncStatus = "No static wallpaper available to sample";
            return;
        }
        root.extractImageUrl = url;
        root.extractingAccent = true;
    }

    function finishAccentExtraction(hex: string) {
        root.extractingAccent = false;
        if (!hex || !hex.startsWith("#")) return;
        root.lastExtractedHex = hex;
        ThemeConfig.setColor("accent", hex);
        root.lastSyncStatus = "Accent matched to wallpaper (" + hex.toUpperCase() + ")";
    }

    function save() {
        store.setText(JSON.stringify({
            syncHyprland: root.syncHyprland,
            syncGtk: root.syncGtk,
            syncQt: root.syncQt,
            autoWallpaperAccent: root.autoWallpaperAccent
        }, null, 2));
    }

    Timer {
        id: syncDebounce
        interval: 450
        onTriggered: root.syncNow()
    }

    Connections {
        target: ThemeConfig
        function on_RevisionChanged() {
            if (!ThemeConfig.ready) return;
            if (root.syncHyprland || root.syncGtk || root.syncQt)
                syncDebounce.restart();
        }
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged() {
            if (root.autoWallpaperAccent && Wallpapers.ready)
                accentDebounce.restart();
        }
        function onModeChanged() {
            if (root.autoWallpaperAccent && Wallpapers.ready)
                accentDebounce.restart();
        }
        function onResolvedSingleImageUrlChanged() {
            if (root.autoWallpaperAccent && Wallpapers.ready)
                accentDebounce.restart();
        }
    }

    Timer {
        id: accentDebounce
        interval: 600
        onTriggered: root.requestWallpaperAccent()
    }

    Process {
        id: qtProc
        command: [
            "python3",
            (Quickshell.env("HOME") || "") + "/.config/qt6ct/make-cosmic-shell-theme.py",
            "--from-theme-json",
            ThemeConfig.stateFile
        ]
        onExited: code => {
            root.syncing = false;
            if (code === 0)
                root.lastSyncStatus = "Qt/KDE/Kvantum updated at " + Qt.formatTime(new Date(), "HH:mm:ss");
        }
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.syncHyprland !== undefined) root.syncHyprland = Boolean(d.syncHyprland);
                    if (d.syncGtk !== undefined) root.syncGtk = Boolean(d.syncGtk);
                    if (d.syncQt !== undefined) root.syncQt = Boolean(d.syncQt);
                    if (d.autoWallpaperAccent !== undefined) root.autoWallpaperAccent = Boolean(d.autoWallpaperAccent);
                }
            } catch (e) {}
        }
    }
}
