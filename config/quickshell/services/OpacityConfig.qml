pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Persistent per-surface opacity configuration:
// - widgetsOpacity:       all bar popups, Quick Settings, Launcher, Capture & widget windows
// - barOpacity:           top panel pill background
// - notificationsOpacity: notification pop-up toasts & notification center
// - osdOpacity:           volume / brightness / keyboard light on-screen toast
// Stored in Quickshell's state dir (opacity-config.json) so changes survive restarts.
Singleton {
    id: root

    property bool settingsOpen: false
    property bool ready: false
    property bool loadedFromFile: false

    readonly property string stateFile: Quickshell.statePath("opacity-config.json")

    readonly property real defaultWidgets: 0.96
    readonly property real defaultBar: 0.66
    readonly property real defaultNotifications: 0.96
    readonly property real defaultOsd: 0.96

    property real widgetsOpacity: defaultWidgets
    property real barOpacity: defaultBar
    property real notificationsOpacity: defaultNotifications
    property real osdOpacity: defaultOsd

    function clamp(v: real): real {
        const n = Number(v);
        if (isNaN(n)) return 0.96;
        return Math.round(Math.max(0, Math.min(1, n)) * 100) / 100;
    }

    function applyToTheme() {
        Theme.widgetsOpacity = root.widgetsOpacity;
        Theme.barOpacity = root.barOpacity;
        Theme.notificationsOpacity = root.notificationsOpacity;
        Theme.osdOpacity = root.osdOpacity;
    }

    onWidgetsOpacityChanged: Theme.widgetsOpacity = root.widgetsOpacity
    onBarOpacityChanged: Theme.barOpacity = root.barOpacity
    onNotificationsOpacityChanged: Theme.notificationsOpacity = root.notificationsOpacity
    onOsdOpacityChanged: Theme.osdOpacity = root.osdOpacity

    Component.onCompleted: applyToTheme()

    function scheduleSave() {
        saveTimer.restart();
    }

    function saveNow() {
        saveTimer.stop();
        store.setText(JSON.stringify({
            widgets: root.widgetsOpacity,
            bar: root.barOpacity,
            notifications: root.notificationsOpacity,
            osd: root.osdOpacity
        }));
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: root.saveNow()
    }

    function notifyThemeConfig() {
        ThemeConfig.syncOpacityFromExternal(
            root.widgetsOpacity,
            root.barOpacity,
            root.notificationsOpacity,
            root.osdOpacity
        );
    }

    function syncFromTheme(widgets: real, bar: real, notifications: real, osd: real) {
        root.widgetsOpacity = clamp(widgets);
        root.barOpacity = clamp(bar);
        root.notificationsOpacity = clamp(notifications);
        root.osdOpacity = clamp(osd);
        scheduleSave();
    }

    function setWidgets(v: real) {
        root.widgetsOpacity = clamp(v);
        scheduleSave();
        notifyThemeConfig();
    }

    function setBar(v: real) {
        root.barOpacity = clamp(v);
        scheduleSave();
        notifyThemeConfig();
    }

    function setNotifications(v: real) {
        root.notificationsOpacity = clamp(v);
        scheduleSave();
        notifyThemeConfig();
    }

    function setOsd(v: real) {
        root.osdOpacity = clamp(v);
        scheduleSave();
        notifyThemeConfig();
    }

    function applyPreset(widgets: real, bar: real, notifications: real, osd: real) {
        root.widgetsOpacity = clamp(widgets);
        root.barOpacity = clamp(bar);
        root.notificationsOpacity = clamp(notifications);
        root.osdOpacity = clamp(osd);
        saveNow();
        notifyThemeConfig();
    }

    function reset() {
        applyPreset(defaultWidgets, defaultBar, defaultNotifications, defaultOsd);
    }

    FileView {
        id: store
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (saved && typeof saved === "object") {
                    if (saved.widgets !== undefined) root.widgetsOpacity = root.clamp(saved.widgets);
                    if (saved.bar !== undefined) root.barOpacity = root.clamp(saved.bar);
                    if (saved.notifications !== undefined) root.notificationsOpacity = root.clamp(saved.notifications);
                    if (saved.osd !== undefined) root.osdOpacity = root.clamp(saved.osd);
                    root.loadedFromFile = true;
                    root.applyToTheme();
                    if (ThemeConfig.ready && !ThemeConfig.loadedFromFile)
                        root.notifyThemeConfig();
                }
            } catch (e) {}
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }

    IpcHandler {
        target: "opacity"
        function toggle(): void { WidgetHistory.opacityFromBarSettings = false; root.settingsOpen = !root.settingsOpen; }
        function open(): void { WidgetHistory.opacityFromBarSettings = false; root.settingsOpen = true; }
        function close(): void { WidgetHistory.opacityFromBarSettings = false; root.settingsOpen = false; }
        function reset(): void { root.reset(); }
    }
}
