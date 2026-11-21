pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// cliphist-backed clipboard history with:
// - Pinned favorite text snippets (persisted independently; preserved across Wipe)
// - Pause History toggle (stops Wayland clipboard watchers immediately)
// - Secret Hygiene toggle (auto-skips copies flagged with x-kde-passwordManagerHint
//   or made while Bitwarden / KeePassXC / 1Password / Proton Pass is focused)
Singleton {
    id: root

    readonly property string pinsFile: Quickshell.statePath("clipboard-pins.json")
    readonly property string configFile: Quickshell.statePath("clipboard-config.json")

    property var entries: []             // [{ id, text, isImage }]
    property var pins: []                // [{ id, text }]
    property bool paused: false
    property bool skipPasswordManagers: true
    readonly property bool loading: list.running

    // Inline secret-hygiene guard for wl-paste --watch (no external scripts):
    // Checks Wayland password-manager MIME hint AND focused Hyprland window class/title.
    readonly property string textStoreCmd:
        "if [ \"$1\" = \"1\" ]; then " +
        "  wl-paste --list-types 2>/dev/null | grep -qiE 'passwordManagerHint|password-manager' && exit 0; " +
        "  win=$(timeout 1 hyprctl activewindow -j 2>/dev/null | tr '[:upper:]' '[:lower:]'); " +
        "  echo \"$win\" | grep -qE 'bitwarden|keepassxc|1password|proton.?pass|vaultwarden|enpass' && exit 0; " +
        "fi; " +
        "cliphist store"

    function refresh() {
        list.running = true;
    }

    function copy(id: string) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", id]);
    }

    function copyPin(text: string) {
        if (!text) return;
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    function remove(id: string) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", id]);
        root.entries = root.entries.filter(e => e.id !== id);
    }

    // Wipes cliphist history while preserving all pinned snippets.
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
    }

    function isPinnedPreview(previewText: string): bool {
        const norm = String(previewText || "").trim();
        if (!norm) return false;
        return root.pins.some(p => {
            const pt = String(p.text || "").trim();
            return pt === norm || pt.replace(/\s+/g, " ").startsWith(norm.slice(0, 60));
        });
    }

    function pinEntry(entry) {
        if (!entry || entry.isImage) return;
        // If already pinned, unpin matching item.
        const norm = String(entry.text || "").trim();
        const existing = root.pins.find(p => {
            const pt = String(p.text || "").trim();
            return pt === norm || pt.replace(/\s+/g, " ").startsWith(norm.slice(0, 60));
        });
        if (existing) {
            unpin(existing.id);
            return;
        }
        // Decode full text from cliphist so multiline snippets pin completely.
        pinDecodeProc.pendingFallback = entry.text;
        pinDecodeProc.command = ["cliphist", "decode", entry.id];
        pinDecodeProc.running = true;
    }

    function addPinText(fullText: string) {
        const clean = String(fullText || "");
        if (clean.trim() === "") return;
        if (root.pins.some(p => p.text === clean)) return;
        const item = { id: String(Date.now()) + "-" + Math.floor(Math.random() * 10000), text: clean };
        root.pins = [item].concat(root.pins);
        savePins();
    }

    function unpin(pinId: string) {
        root.pins = root.pins.filter(p => p.id !== pinId);
        savePins();
    }

    function togglePaused() {
        root.paused = !root.paused;
        saveConfig();
    }

    function toggleSkipPasswordManagers() {
        root.skipPasswordManagers = !root.skipPasswordManagers;
        saveConfig();
    }

    function savePins() {
        pinsStore.setText(JSON.stringify(root.pins, null, 2));
    }

    function saveConfig() {
        cfgStore.setText(JSON.stringify({
            paused: root.paused,
            skipPasswordManagers: root.skipPasswordManagers
        }, null, 2));
    }

    // Clean up any legacy bare `wl-paste --type ... --watch cliphist store` from before
    // Clipboard.qml managed the watchers directly.
    Process {
        id: legacyCleanup
        running: true
        command: ["sh", "-c", "pkill -f '^wl-paste --type (text|image) --watch cliphist store$' 2>/dev/null || true"]
        onExited: root._watchersReady = true
    }
    property bool _watchersReady: false

    // Managed text clipboard watcher (auto-stops when paused, restarts cleanly if secret hygiene changes)
    Process {
        id: textWatcher
        running: root._watchersReady && !root.paused
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", root.textStoreCmd, "sh", root.skipPasswordManagers ? "1" : "0"]
    }

    // Managed image clipboard watcher
    Process {
        id: imageWatcher
        running: root._watchersReady && !root.paused
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }

    // Restart textWatcher when skipPasswordManagers changes so the new flag takes effect immediately.
    onSkipPasswordManagersChanged: {
        if (textWatcher.running) {
            textWatcher.running = false;
            watcherRestartTimer.restart();
        }
    }
    Timer {
        id: watcherRestartTimer
        interval: 80
        onTriggered: if (root._watchersReady && !root.paused) textWatcher.running = true
    }

    Process {
        id: pinDecodeProc
        property string pendingFallback: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const decoded = text;
                root.addPinText(decoded !== "" ? decoded : pinDecodeProc.pendingFallback);
            }
        }
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    const t = l.slice(tab + 1);
                    return { id: l.slice(0, tab), text: t, isImage: t.startsWith("[[ binary data") };
                });
            }
        }
    }

    FileView {
        id: pinsStore
        path: root.pinsFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d)) root.pins = d;
            } catch (e) {}
        }
    }

    FileView {
        id: cfgStore
        path: root.configFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.paused !== undefined) root.paused = Boolean(d.paused);
                    if (d.skipPasswordManagers !== undefined) root.skipPasswordManagers = Boolean(d.skipPasswordManagers);
                }
            } catch (e) {}
        }
    }
}
