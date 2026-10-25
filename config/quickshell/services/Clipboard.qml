pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// cliphist-backed clipboard history (the watchers run from hypr/conf/autostart.lua).
Singleton {
    id: root

    property var entries: []   // [{ id, text, isImage }]
    readonly property bool loading: list.running

    function refresh() {
        list.running = true;
    }
    function copy(id: string) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", id]);
    }
    function remove(id: string) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", id]);
        root.entries = root.entries.filter(e => e.id !== id);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
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
}
