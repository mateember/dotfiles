pragma Singleton

import QtQuick
import Quickshell

// Open state of the quick settings panel, shared by the panel, the bar button and IPC.
// `asWindow = true` opens Quick Settings as a real Wayland FloatingWindow (from the Launcher).
Singleton {
    id: root

    property bool open: false
    property bool asWindow: false
    property string targetScreen: ""
    property double closedAt: 0

    onOpenChanged: if (!open) closedAt = Date.now()

    // A click on the bar button first closes the panel (click outside), then toggles:
    // ignore that toggle so the button closes the panel instead of reopening it.
    function toggle() {
        if (!root.open && Date.now() - root.closedAt < 300) return;
        WidgetHistory.clear();
        root.targetScreen = "";
        root.asWindow = false;
        root.open = !root.open;
    }

    function openFresh() {
        WidgetHistory.clear();
        root.targetScreen = "";
        root.asWindow = false;
        root.open = true;
    }

    function openWindow() {
        WidgetHistory.clear();
        root.targetScreen = "";
        root.asWindow = true;
        root.open = true;
    }

    function restore(screen: string, winMode: bool) {
        Popups.hide();
        root.targetScreen = screen;
        root.asWindow = winMode;
        root.open = true;
    }

    function hide() {
        root.open = false;
    }

    function close() {
        WidgetHistory.clear();
        root.hide();
    }
}
