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

    function toggle(id: string) {
        const winMode = !isBarVisible(id);
        if (root.current === id && root.asWindow === winMode && !root.fromQuickSettings) {
            root.close();
        } else {
            WidgetHistory.clear();
            root.asWindow = winMode;
            root.fromQuickSettings = false;
            root.current = id;
        }
    }
    function open(id: string) {
        WidgetHistory.clear();
        root.asWindow = !isBarVisible(id);
        root.fromQuickSettings = false;
        root.current = id;
    }
    function openChildFromQuickSettings(id: string, qsScreen: string, qsAsWindow: bool) {
        WidgetHistory.push({ kind: "quicksettings", screen: qsScreen, asWindow: qsAsWindow });
        QuickSettingsState.hide();
        root.asWindow = qsAsWindow;
        root.fromQuickSettings = !qsAsWindow;
        root.current = id;
    }
    function openFromQuickSettings(id: string) {
        const scr = id.split("@")[1] || "";
        openChildFromQuickSettings(id, scr, QuickSettingsState.asWindow);
    }
    function openWindow(id: string) {
        WidgetHistory.clear();
        root.asWindow = true;
        root.fromQuickSettings = false;
        root.current = id;
    }
    function restore(id: string, winMode: bool, fromQs: bool) {
        QuickSettingsState.hide();
        root.asWindow = winMode;
        root.fromQuickSettings = fromQs;
        root.current = id;
    }
    function hide() {
        root.current = "";
        root.asWindow = false;
        root.fromQuickSettings = false;
    }
    function close() {
        WidgetHistory.clear();
        root.hide();
    }
}
