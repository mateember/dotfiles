pragma Singleton

import QtQuick
import Quickshell

// Caffeine state. The actual IdleInhibitor lives in each bar window (it needs a surface).
// Kept across hot reloads.
Singleton {
    id: root

    readonly property bool caffeine: persist.caffeine

    function toggle() {
        persist.caffeine = !persist.caffeine;
    }

    PersistentProperties {
        id: persist
        reloadableId: "hcs-idle"
        property bool caffeine: false
    }
}
