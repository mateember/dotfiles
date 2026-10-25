pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Screen color picker (hyprpicker). The picked color is copied as #RRGGBB and shown in the OSD.
//   qs -p <root>/shell ipc call picker color      (SUPER SHIFT P)
Singleton {
    id: root

    property var recent: []   // last picked colors, newest first

    function pick() {
        if (proc.running) return;
        Popups.close();
        proc.running = true;
    }

    Process {
        id: proc
        // Small delay so a closing popup isn't picked.
        command: ["sh", "-c", "sleep 0.2; hyprpicker --format=hex --no-fancy --quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.toUpperCase().match(/#[0-9A-F]{6}/);
                if (!m) return;   // cancelled with Escape
                const hex = m[0];
                Quickshell.execDetached(["wl-copy", hex]);
                root.recent = [hex].concat(root.recent.filter(c => c !== hex)).slice(0, 8);
                Osd.showColor(hex);
            }
        }
    }

    IpcHandler {
        target: "picker"
        function color(): void { root.pick(); }
    }
}
