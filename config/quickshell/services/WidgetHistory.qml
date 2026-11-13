pragma Singleton

import QtQuick
import Quickshell

// Navigation history stack for drill-down widget transitions (Escape / ← to step back).
// Tracks two independent scopes:
// 1. `stack`: transient popup/panel/overlay chain (QuickSettings <-> Popup <-> CaptureOverlay).
// 2. `opacityFromBarSettings`: settings window drill-down (BarSettingsWindow -> OpacitySettingsWindow),
//    kept separate so live-previewing bar popups or Quick Settings while adjusting opacity
//    does not wipe out the settings window's back target.
Singleton {
    id: root

    property var stack: []
    readonly property bool canGoBack: stack.length > 0

    property bool opacityFromBarSettings: false
    property string themeOrigin: ""   // "" | "barsettings" | "opacity"

    function push(entry: var) {
        if (!entry) return;
        root.stack = root.stack.concat([entry]);
    }

    function clear() {
        if (root.stack.length > 0)
            root.stack = [];
    }

    function popAndRestore(): bool {
        if (root.stack.length === 0) return false;
        const next = root.stack.slice(0, root.stack.length - 1);
        const entry = root.stack[root.stack.length - 1];
        root.stack = next;

        if (entry.kind === "quicksettings") {
            QuickSettingsState.restore(entry.screen || "", Boolean(entry.asWindow));
            return true;
        }
        if (entry.kind === "popup") {
            Popups.restore(entry.id || "", Boolean(entry.asWindow), Boolean(entry.fromQuickSettings));
            return true;
        }
        return false;
    }

    function backFromPopup() {
        if (!popAndRestore())
            Popups.close();
    }

    function backFromCapture() {
        Recorder.hideOverlay();
        if (!popAndRestore())
            root.clear();
    }

    function openOpacityFromBarSettings() {
        root.opacityFromBarSettings = true;
        BarConfig.settingsOpen = false;
        OpacityConfig.settingsOpen = true;
    }

    function backFromOpacitySettings() {
        const returnToBar = root.opacityFromBarSettings;
        root.opacityFromBarSettings = false;
        OpacityConfig.settingsOpen = false;
        if (returnToBar)
            BarConfig.settingsOpen = true;
    }

    function closeOpacitySettings() {
        root.opacityFromBarSettings = false;
        OpacityConfig.settingsOpen = false;
    }

    function openThemeStandalone() {
        root.themeOrigin = "";
        ThemeConfig.settingsOpen = true;
    }

    function openThemeFromBarSettings() {
        root.themeOrigin = "barsettings";
        BarConfig.settingsOpen = false;
        ThemeConfig.settingsOpen = true;
    }

    function openThemeFromOpacitySettings() {
        root.themeOrigin = "opacity";
        OpacityConfig.settingsOpen = false;
        ThemeConfig.settingsOpen = true;
    }

    function backFromThemeSettings() {
        const origin = root.themeOrigin;
        root.themeOrigin = "";
        ThemeConfig.settingsOpen = false;
        if (origin === "barsettings")
            BarConfig.settingsOpen = true;
        else if (origin === "opacity")
            OpacityConfig.settingsOpen = true;
    }

    function closeThemeSettings() {
        root.themeOrigin = "";
        ThemeConfig.settingsOpen = false;
    }
}
