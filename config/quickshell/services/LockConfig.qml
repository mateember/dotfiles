pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared persistent lock screen & idle configuration (~/.local/state/quickshell/hcs-lock.json).
// Read by both `shell.qml` (HCS Settings -> Lock Screen & Security) and `lock.qml` (`LockScreen` / `LockSurface`).
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell"
    readonly property string stateFile: stateDir + "/hcs-lock.json"

    property bool passiveMode: false
    property bool loaded: false
    property bool howdyEnabled: true
    property string customGreeting: ""
    property string avatarPath: ""
    property int _thumbRev: 0
    property bool _thumbPending: false
    property bool showCapsAndLayout: true
    property bool showWeather: true
    property bool showNextEvent: true
    property bool showNotifCount: true
    property bool showPowerActions: true

    // Live Howdy hardware/PAM probe (so Settings can show status without locking)
    property bool howdyInstalled: false
    property bool howdyModelPresent: false
    property string howdyStatusText: "Checking…"

    // Parsed hypridle.conf timeouts (display-only overview)
    property var idleListeners: []

    property bool _ignoreNextChange: false

    function normalizePath(p: string): string {
        let s = (p || "").trim();
        if (s.startsWith("file://")) {
            try { s = decodeURIComponent(s.slice(7)); }
            catch (e) { s = s.slice(7); }
        }
        const home = Quickshell.env("HOME") || "";
        if (home) {
            if (s === "~") s = home;
            else if (s.startsWith("~/")) s = home + s.slice(1);
        }
        while (s.length > 1 && s.endsWith("/")) s = s.slice(0, -1);
        return s;
    }

    function isSafeLocalPath(p: string): bool {
        const s = normalizePath(p);
        return s.startsWith("/") && !/[\x00-\x1f\x7f]/.test(s);
    }

    function pathToUrl(p: string): string {
        const clean = normalizePath(p);
        if (!clean) return "";
        return "file://" + clean.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }

    function hashString(str: string): string {
        let h = 2166136261;
        for (let i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 16777619);
        }
        return (h >>> 0).toString(16);
    }

    function avatarThumbPathFor(p: string): string {
        const clean = normalizePath(p);
        if (!isSafeLocalPath(clean)) return "";
        return root.cacheDir + "/hcs-avatar-" + hashString(clean) + ".png";
    }

    readonly property string avatarThumbUrl: {
        const tp = avatarThumbPathFor(root.avatarPath);
        if (!tp) return "";
        return pathToUrl(tp) + (root._thumbRev > 0 ? ("?v=" + root._thumbRev) : "");
    }

    readonly property string avatarFallbackUrl: {
        const clean = normalizePath(root.avatarPath);
        return clean ? pathToUrl(clean) : "";
    }

    function ensureAvatarThumb(): void {
        if (root.passiveMode) return;
        if (thumbProc.running) {
            root._thumbPending = true;
            return;
        }
        const clean = normalizePath(root.avatarPath);
        if (!clean) {
            thumbProc.command = [
                "sh", "-c",
                'rm -f "$1"/hcs-avatar-*.png "$1"/hcs-avatar-*.png.tmp.*',
                "sh", root.cacheDir
            ];
            thumbProc.running = true;
            return;
        }
        if (!isSafeLocalPath(clean)) return;
        const outPath = avatarThumbPathFor(clean);
        thumbProc.command = [
            "sh", "-c",
            'mkdir -p "$3"; ' +
            'if [ ! -s "$2" ] || [ "$4" -nt "$2" ]; then ' +
            '  tmp="$2.tmp.$$"; ' +
            '  if ffmpeg -y -v error -i "$1" -frames:v 1 -vf "scale=256:256:force_original_aspect_ratio=increase:flags=lanczos,crop=256:256" -f image2 -c:v png "$tmp" && [ -s "$tmp" ]; then ' +
            '    mv -f "$tmp" "$2"; ' +
            '    for f in "$3"/hcs-avatar-*.png "$3"/hcs-avatar-*.png.tmp.*; do [ "$f" = "$2" ] || rm -f "$f"; done; ' +
            '  else ' +
            '    rm -f "$tmp"; exit 1; ' +
            '  fi; ' +
            'fi',
            "sh", "file:" + clean, outPath, root.cacheDir, clean
        ];
        thumbProc.running = true;
    }

    function setHowdyEnabled(v: bool) { root.howdyEnabled = v; save(); }
    function setCustomGreeting(s: string) { root.customGreeting = s; save(); }
    function setAvatarPath(s: string) { root.avatarPath = normalizePath(s); save(); ensureAvatarThumb(); }
    function setShowCapsAndLayout(v: bool) { root.showCapsAndLayout = v; save(); }
    function setShowWeather(v: bool) { root.showWeather = v; save(); }
    function setShowNextEvent(v: bool) { root.showNextEvent = v; save(); }
    function setShowNotifCount(v: bool) { root.showNotifCount = v; save(); }
    function setShowPowerActions(v: bool) { root.showPowerActions = v; save(); }

    function reset() {
        root.howdyEnabled = true;
        root.customGreeting = "";
        root.avatarPath = "";
        root.showCapsAndLayout = true;
        root.showWeather = true;
        root.showNextEvent = true;
        root.showNotifCount = true;
        root.showPowerActions = true;
        save();
        ensureAvatarThumb();
    }

    function pickAvatar() {
        if (!avatarPicker.running) avatarPicker.running = true;
    }

    function testLockNow() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    function refreshProbes() {
        if (!howdyProbe.running) howdyProbe.running = true;
        hypridleFile.reload();
    }

    function save() {
        root._ignoreNextChange = true;
        ignoreTimer.restart();
        store.setText(JSON.stringify({
            howdyEnabled: root.howdyEnabled,
            customGreeting: root.customGreeting,
            avatarPath: root.avatarPath,
            showCapsAndLayout: root.showCapsAndLayout,
            showWeather: root.showWeather,
            showNextEvent: root.showNextEvent,
            showNotifCount: root.showNotifCount,
            showPowerActions: root.showPowerActions
        }, null, 2));
    }

    Timer {
        id: ignoreTimer
        interval: 400
        onTriggered: root._ignoreNextChange = false
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!root._ignoreNextChange) reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.howdyEnabled !== undefined) root.howdyEnabled = Boolean(d.howdyEnabled);
                    if (d.customGreeting !== undefined) root.customGreeting = String(d.customGreeting);
                    if (d.avatarPath !== undefined) root.avatarPath = String(d.avatarPath);
                    if (d.showCapsAndLayout !== undefined) root.showCapsAndLayout = Boolean(d.showCapsAndLayout);
                    if (d.showWeather !== undefined) root.showWeather = Boolean(d.showWeather);
                    if (d.showNextEvent !== undefined) root.showNextEvent = Boolean(d.showNextEvent);
                    if (d.showNotifCount !== undefined) root.showNotifCount = Boolean(d.showNotifCount);
                    if (d.showPowerActions !== undefined) root.showPowerActions = Boolean(d.showPowerActions);
                }
            } catch (e) {}
            root.loaded = true;
            Qt.callLater(() => root.ensureAvatarThumb());
        }
        onLoadFailed: root.loaded = true
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.stateDir, root.cacheDir]
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (!root.passiveMode && !mkdirProc.running) mkdirProc.running = true;
        });
    }

    Process {
        id: thumbProc
        onExited: code => {
            if (code === 0) root._thumbRev++;
            if (root._thumbPending) {
                root._thumbPending = false;
                Qt.callLater(() => root.ensureAvatarThumb());
            }
        }
    }

    FileView {
        id: hypridleFile
        path: (Quickshell.env("HOME") || "") + "/.config/hypr/hypridle.conf"
        printErrors: false
        onLoaded: {
            const lines = text().split("\n");
            const out = [];
            let inListener = false;
            let secs = -1;
            let cmd = "";
            for (let i = 0; i < lines.length; i++) {
                // Strip comments outside quotes (hypridle.conf lines are simple key = val)
                const rawLine = lines[i].replace(/^\s*#.*$/, "").trim();
                if (!rawLine) continue;
                if (!inListener) {
                    if (/^listener\s*\{/.test(rawLine)) {
                        inListener = true;
                        secs = -1;
                        cmd = "";
                    }
                    continue;
                }
                if (rawLine === "}") {
                    if (secs >= 0) {
                        let label = "Idle Action";
                        if (cmd.includes("lock")) label = "Lock Session";
                        else if (cmd.includes("dpms")) label = "Turn Off Display (DPMS)";
                        else if (cmd.includes("suspend")) label = "Suspend System";
                        else if (cmd.includes("brightness")) label = "Dim Screen";
                        const mins = Math.floor(secs / 60);
                        const rem = secs % 60;
                        const fmt = mins > 0 ? (rem > 0 ? `${mins}m ${rem}s` : `${mins} min`) : `${secs} s`;
                        out.push({ seconds: secs, formatted: fmt, label: label, command: cmd });
                    }
                    inListener = false;
                    continue;
                }
                const tm = rawLine.match(/^timeout\s*=\s*(\d+)/);
                if (tm) secs = parseInt(tm[1]);
                const onTm = rawLine.match(/^on-timeout\s*=\s*(.+)$/);
                if (onTm) cmd = onTm[1].trim();
            }
            root.idleListeners = out;
        }
    }

    Process {
        id: howdyProbe
        command: [
            "sh", "-c",
            "user=\"${USER:-$(id -un)}\"; " +
            "pam=0; grep -q pam_howdy /etc/pam.d/qs-lock-face 2>/dev/null && pam=1; " +
            "model=0; " +
            "for d in /var/lib/howdy/models /etc/howdy/models /lib/security/howdy/models; do " +
            "  [ -s \"$d/$user.dat\" ] && model=1 && break; " +
            "done; " +
            "printf '%s %s\\n' \"$pam\" \"$model\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                root.howdyInstalled = parts[0] === "1";
                root.howdyModelPresent = parts[1] === "1";
                if (!root.howdyInstalled) root.howdyStatusText = "PAM service qs-lock-face not configured";
                else if (!root.howdyModelPresent) root.howdyStatusText = "Installed · no readable face model (or root-only)";
                else root.howdyStatusText = "Ready · IR face model enrolled";
            }
        }
    }

    Process {
        id: avatarPicker
        command: ["zenity", "--file-selection", "--title=Select Lock Screen Avatar", "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p) root.setAvatarPath(p);
            }
        }
    }
}
