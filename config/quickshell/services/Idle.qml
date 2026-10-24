pragma Singleton

import QtQuick
import Quickshell

// Caffeine state (indefinite or fixed timer). The actual IdleInhibitor lives in each bar window.
// Kept across hot reloads.
Singleton {
    id: root

    readonly property bool caffeine: persist.caffeine
    readonly property int durationMinutes: persist.durationMinutes
    readonly property double endTimeMs: persist.endTimeMs
    property int remainingSeconds: 0

    readonly property string remainingText: {
        if (!root.caffeine) return "Off";
        if (root.endTimeMs <= 0) return "Indefinitely";
        const s = Math.max(0, root.remainingSeconds);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        if (h > 0) return h + "h " + (m < 10 ? "0" : "") + m + "m";
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    readonly property string shortRemainingText: {
        if (!root.caffeine || root.endTimeMs <= 0) return "";
        const s = Math.max(0, root.remainingSeconds);
        if (s >= 3600) return Math.ceil(s / 60) + "m";
        if (s >= 60) return Math.ceil(s / 60) + "m";
        return s + "s";
    }

    readonly property string statusText: {
        if (!root.caffeine) return "Off";
        if (root.endTimeMs <= 0) return "Indefinitely";
        return root.remainingText + " left";
    }

    // Left click: if on (either timed or indefinite), turn off; if off, turn on indefinitely.
    function toggle() {
        if (persist.caffeine) {
            root.disable();
        } else {
            root.enableIndefinite();
        }
    }

    function enableIndefinite() {
        persist.durationMinutes = 0;
        persist.endTimeMs = 0;
        root.remainingSeconds = 0;
        persist.caffeine = true;
    }

    function enableFor(minutes: int) {
        if (minutes <= 0) {
            if (persist.caffeine && persist.durationMinutes === 0) root.disable();
            else root.enableIndefinite();
            return;
        }
        if (persist.caffeine && persist.durationMinutes === minutes) {
            root.disable();
            return;
        }
        persist.durationMinutes = minutes;
        persist.endTimeMs = Date.now() + minutes * 60000;
        root.remainingSeconds = minutes * 60;
        persist.caffeine = true;
    }

    function disable() {
        persist.caffeine = false;
        persist.durationMinutes = 0;
        persist.endTimeMs = 0;
        root.remainingSeconds = 0;
    }

    function syncRemaining() {
        if (!persist.caffeine || persist.endTimeMs <= 0) {
            root.remainingSeconds = 0;
            return;
        }
        const rem = Math.ceil((persist.endTimeMs - Date.now()) / 1000);
        if (rem <= 0) {
            root.disable();
        } else {
            root.remainingSeconds = rem;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: persist.caffeine && persist.endTimeMs > 0
        triggeredOnStart: true
        onTriggered: root.syncRemaining()
    }

    PersistentProperties {
        id: persist
        reloadableId: "hcs-idle"
        property bool caffeine: false
        property int durationMinutes: 0
        property double endTimeMs: 0
    }
}
