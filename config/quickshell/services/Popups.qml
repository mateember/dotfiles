pragma Singleton

import QtQuick
import Quickshell

// Which bar popup is open. Only one at a time, across all screens.
// Ids look like "<name>@<screen>", e.g. "volume@eDP-1".
// - Clicked on the bar (`open` / `toggle`): opens anchored below its bar icon (or as a centered
//   FloatingWindow if the module is hidden on the bar).
// - Opened from Quick Settings (`openFromQuickSettings`): always opens as a dropdown in the
//   top-right Quick Settings position, even if the module is hidden on the bar.
// - Launched from the Launcher (`openWindow`): opens as a centered FloatingWindow.
Singleton {
    id: root

    property string current: ""
    property bool asWindow: false
    property bool fromQuickSettings: false

    function barIdFor(popupId: string): string {
        const name = popupId.split("@")[0];
        return name === "calendar" ? "clock" : name;
    }

    function isBarVisible(popupId: string): bool {
        return BarConfig.isEnabled(barIdFor(popupId));
    }

    function applyOpen(id: string, winMode: bool, fromQs: bool) {
        if (root.current !== "" && root.current !== id)
            root.current = "";
        root.asWindow = winMode;
        root.fromQuickSettings = fromQs;
        root.current = id;
    }

    function toggle(id: string) {
        const winMode = !isBarVisible(id);
        if (root.current === id && root.asWindow === winMode && !root.fromQuickSettings) {
            root.close();
        } else {
            if (root.current !== "" && root.current !== id)
                root.current = "";
            WidgetHistory.clear();
            applyOpen(id, winMode, false);
        }
    }
    function open(id: string) {
        if (root.current !== "" && root.current !== id)
            root.current = "";
        WidgetHistory.clear();
        applyOpen(id, !isBarVisible(id), false);
    }
    function openChildFromQuickSettings(id: string, qsScreen: string, qsAsWindow: bool) {
        if (root.current !== "" && root.current !== id)
            root.current = "";
        WidgetHistory.push({ kind: "quicksettings", screen: qsScreen, asWindow: qsAsWindow });
        QuickSettingsState.hide();
        applyOpen(id, qsAsWindow, !qsAsWindow);
    }
    function openFromQuickSettings(id: string) {
        const scr = id.split("@")[1] || "";
        openChildFromQuickSettings(id, scr, QuickSettingsState.asWindow);
    }
    function openWindow(id: string) {
        if (root.current !== "" && root.current !== id)
            root.current = "";
        WidgetHistory.clear();
        applyOpen(id, true, false);
    }
    function restore(id: string, winMode: bool, fromQs: bool) {
        if (root.current !== "" && root.current !== id)
            root.current = "";
        QuickSettingsState.hide();
        applyOpen(id, winMode, fromQs);
    }
    function hide() {
        root.current = "";
        root.asWindow = false;
        root.fromQuickSettings = false;
    }
    function close() {
        root.hide();
        WidgetHistory.clear();
    }
}
