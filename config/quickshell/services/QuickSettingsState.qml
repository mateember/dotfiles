pragma Singleton

import QtQuick
import Quickshell

// Open state of the quick settings panel, shared by the panel, the bar button and IPC.
// `asWindow = true` opens Quick Settings as a real Wayland FloatingWindow (from the Launcher).
Singleton {
    id: root

    property bool open: false
    property bool asWindow: false
    property double closedAt: 0

    onOpenChanged: if (!open) { closedAt = Date.now(); asWindow = false; }

    // A click on the bar button first closes the panel (click outside), then toggles:
    // ignore that toggle so the button closes the panel instead of reopening it.
    function toggle() {
        if (!root.open && Date.now() - root.closedAt < 300) return;
        root.asWindow = false;
        root.open = !root.open;
    }

    function openWindow() {
        root.asWindow = true;
        root.open = true;
    }

    function close() {
        root.open = false;
    }
}
