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
            root.current = "";
            root.asWindow = false;
            root.fromQuickSettings = false;
        } else {
            root.asWindow = winMode;
            root.fromQuickSettings = false;
            root.current = id;
        }
    }
    function open(id: string) {
        root.asWindow = !isBarVisible(id);
        root.fromQuickSettings = false;
        root.current = id;
    }
    function openFromQuickSettings(id: string) {
        root.asWindow = false;
        root.fromQuickSettings = true;
        root.current = id;
    }
    function openWindow(id: string) {
        root.asWindow = true;
        root.fromQuickSettings = false;
        root.current = id;
    }
    function close() {
        root.current = "";
        root.asWindow = false;
        root.fromQuickSettings = false;
    }
}
