pragma Singleton

import QtQuick
import Quickshell

// Shared hover-tooltip state consumed by the single HoverTooltip PopupWindow in shell.qml.
// Avoids allocating dozens of Wayland popup surfaces while giving instant warm transitions
// when gliding across adjacent bar icons.
Singleton {
    id: root

    property Item anchorItem: null
    property string text: ""
    property string subtext: ""
    property bool shown: false

    onAnchorItemChanged: if (!anchorItem && shown) clear()
    Connections {
        target: root.anchorItem
        function onVisibleChanged() { if (root.anchorItem && !root.anchorItem.visible && root.shown) root.clear(); }
    }

    property Item _pendingItem: null
    property string _pendingText: ""
    property string _pendingSubtext: ""
    property double _lastHiddenMs: 0

    function requestShow(item: Item, label: string, sub: string) {
        const clean = (label || "").trim();
        if (!item || clean === "") return;
        if (Popups.current !== "" || QuickSettingsState.open) {
            clear();
            return;
        }
        root._pendingItem = item;
        root._pendingText = clean;
        root._pendingSubtext = (sub || "").trim();

        // Warm transition: show immediately if already visible or hidden < 300 ms ago.
        if (root.shown || (Date.now() - root._lastHiddenMs) < 300) {
            dwellTimer.stop();
            commitShow();
        } else {
            dwellTimer.restart();
        }
    }

    function updateText(item: Item, label: string, sub: string) {
        if (root.anchorItem === item && root.shown) {
            root.text = (label || "").trim();
            root.subtext = (sub || "").trim();
            if (root.text === "") clear();
        } else if (root._pendingItem === item) {
            root._pendingText = (label || "").trim();
            root._pendingSubtext = (sub || "").trim();
        }
    }

    function hide(item: Item) {
        if (item && root._pendingItem === item) {
            dwellTimer.stop();
            root._pendingItem = null;
        }
        if (!item || root.anchorItem === item) {
            if (root.shown) root._lastHiddenMs = Date.now();
            root.shown = false;
            root.anchorItem = null;
        }
    }

    function clear() {
        dwellTimer.stop();
        root._pendingItem = null;
        if (root.shown) root._lastHiddenMs = Date.now();
        root.shown = false;
        root.anchorItem = null;
    }

    function commitShow() {
        if (!root._pendingItem || !root._pendingItem.visible) return;
        if (Popups.current !== "" || QuickSettingsState.open) return;
        root.anchorItem = root._pendingItem;
        root.text = root._pendingText;
        root.subtext = root._pendingSubtext;
        root.shown = true;
    }

    Timer {
        id: dwellTimer
        interval: 420
        onTriggered: root.commitShow()
    }

    Connections {
        target: Popups
        function onCurrentChanged() { if (Popups.current !== "") root.clear(); }
    }
    Connections {
        target: QuickSettingsState
        function onOpenChanged() { if (QuickSettingsState.open) root.clear(); }
    }
}
