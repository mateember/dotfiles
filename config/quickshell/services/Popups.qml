pragma Singleton

import QtQuick
import Quickshell

// Which bar popup is open. Only one at a time, across all screens.
// Ids look like "<name>@<screen>", e.g. "volume@eDP-1".
Singleton {
    id: root

    property string current: ""

    function toggle(id: string) {
        root.current = root.current === id ? "" : id;
    }
    function open(id: string) {
        root.current = id;
    }
    function close() {
        root.current = "";
    }
}
