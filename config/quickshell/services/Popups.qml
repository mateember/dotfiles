pragma Singleton

import QtQuick
import Quickshell

// Which bar popup is open. Only one at a time, across all screens.
// Ids look like "<name>@<screen>", e.g. "volume@eDP-1".
// When `asWindow` is true (launched from the Launcher), the popup opens as a real
// Wayland FloatingWindow centered by Hyprland instead of a bar dropdown.
Singleton {
    id: root

    property string current: ""
    property bool asWindow: false

    function toggle(id: string) {
        if (root.current === id && !root.asWindow) {
            root.current = "";
        } else {
            root.asWindow = false;
            root.current = id;
        }
    }
    function open(id: string) {
        root.asWindow = false;
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
