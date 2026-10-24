pragma Singleton

import QtQuick
import Quickshell

// Which bar popup is open. Only one at a time, across all screens.
// Ids look like "<name>@<screen>", e.g. "volume@eDP-1".
// When `asWindow` is true (launched from the Launcher, or when the module is hidden on the bar),
// the popup opens as a real Wayland FloatingWindow centered by Hyprland instead of a bar dropdown.
Singleton {
    id: root

    property string current: ""
    property bool asWindow: false

    function barIdFor(popupId: string): string {
        const name = popupId.split("@")[0];
        return name === "calendar" ? "clock" : name;
    }

    function isBarVisible(popupId: string): bool {
        return BarConfig.isEnabled(barIdFor(popupId));
    }

    function toggle(id: string) {
        const winMode = !isBarVisible(id);
        if (root.current === id && root.asWindow === winMode) {
            root.current = "";
            root.asWindow = false;
        } else {
            root.asWindow = winMode;
            root.current = id;
        }
    }
    function open(id: string) {
        root.asWindow = !isBarVisible(id);
        root.current = id;
    }
    function openWindow(id: string) {
        root.asWindow = true;
        root.current = id;
    }
    function close() {
        root.current = "";
        root.asWindow = false;
    }
}
