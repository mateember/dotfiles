pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Emoji list from Unicode's emoji-test.txt (path from the flake: $HCS_EMOJI_FILE).
// search("fire") → [{ char, name, group }]. Typing goes through wtype into the focused window.
Singleton {
    id: root

    property var all: []   // [{ char, name, group }]
    readonly property bool available: all.length > 0

    function search(q: string, limit: int): var {
        q = q.trim().toLowerCase();
        if (q === "") return root.all.slice(0, limit);
        const words = q.split(/\s+/);
        const hits = [];
        for (const e of root.all) {
            const hay = e.name + " " + e.group;
            if (words.every(w => hay.includes(w))) {
                hits.push({ e, s: e.name.startsWith(q) ? 0 : e.name.includes(q) ? 1 : 2 });
            }
        }
        hits.sort((a, b) => a.s - b.s);
        return hits.slice(0, limit).map(h => h.e);
    }

    // Copy, and type it into the window that had focus before the launcher opened.
    function insert(ch: string, typeIt: bool) {
        Quickshell.execDetached(["wl-copy", ch]);
        if (typeIt) Quickshell.execDetached(["sh", "-c", 'sleep 0.25; wtype -- "$1"', "sh", ch]);
    }

    FileView {
        path: Quickshell.env("HCS_EMOJI_FILE") ?? ""
        printErrors: false
        onLoaded: {
            const out = [];
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("# subgroup:")) { group = line.slice(11).trim().replace(/-/g, " "); continue; }
                const m = line.match(/; fully-qualified\s+# (\S+) E[\d.]+ (.+)$/);
                if (m) out.push({ char: m[1], name: m[2].toLowerCase(), group });
            }
            root.all = out;
        }
    }
}
