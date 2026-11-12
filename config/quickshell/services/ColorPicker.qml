pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Screen color picker (hyprpicker); copies #RRGGBB and shows OSD (qs ipc call picker color).
Singleton {
    id: root

    property var recent: []   // last picked colors, newest first
    property var pendingCallback: null

    function pick() {
        root.pendingCallback = null;
        if (proc.running) return;
        Popups.close();
        proc.running = true;
    }

    function pickWith(cb) {
        if (proc.running) return;
        root.pendingCallback = cb;
        Popups.close();
        proc.running = true;
    }

    Process {
        id: proc
        // Small delay so a closing popup isn't picked.
        command: ["sh", "-c", "sleep 0.2; hyprpicker --format=hex --no-fancy --quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cb = root.pendingCallback;
                root.pendingCallback = null;
                const m = text.toUpperCase().match(/#[0-9A-F]{6}/);
                if (!m) {
                    if (cb) cb("");
                    return;   // cancelled with Escape
                }
                const hex = m[0];
                Quickshell.execDetached(["wl-copy", hex]);
                root.recent = [hex].concat(root.recent.filter(c => c !== hex)).slice(0, 8);
                if (cb) cb(hex);
                else Osd.showColor(hex);
            }
        }
    }

    IpcHandler {
        target: "picker"
        function color(): void { root.pick(); }
    }
}
