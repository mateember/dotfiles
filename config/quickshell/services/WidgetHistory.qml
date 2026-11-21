pragma Singleton

import QtQuick
import Quickshell

// Navigation history stack for drill-down widget transitions (Escape / ← to step back)
// across transient popups, Quick Settings, and Capture Studio.
Singleton {
    id: root

    property var stack: []
    readonly property bool canGoBack: stack.length > 0

    function push(entry: var) {
        if (!entry) return;
        root.stack = root.stack.concat([entry]);
    }

    function clear() {
        if (root.stack.length > 0)
            root.stack = [];
    }

    function popAndRestore(): bool {
        if (root.stack.length === 0) return false;
        const next = root.stack.slice(0, root.stack.length - 1);
        const entry = root.stack[root.stack.length - 1];
        root.stack = next;

        if (entry.kind === "quicksettings") {
            QuickSettingsState.restore(entry.screen || "", Boolean(entry.asWindow));
            return true;
        }
        if (entry.kind === "popup") {
            Popups.restore(entry.id || "", Boolean(entry.asWindow), Boolean(entry.fromQuickSettings));
            return true;
        }
        return false;
    }

    function backFromPopup() {
        if (!popAndRestore())
            Popups.close();
    }

    function backFromCapture() {
        Recorder.hideOverlay();
        if (!popAndRestore())
            root.clear();
    }
}
