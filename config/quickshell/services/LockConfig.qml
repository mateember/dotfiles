pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared persistent lock screen & idle configuration (~/.local/state/quickshell/hcs-lock.json).
// Read by both `shell.qml` (HCS Settings -> Lock Screen & Security) and `lock.qml` (`LockScreen` / `LockSurface`).
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string stateFile: stateDir + "/hcs-lock.json"

    property bool howdyEnabled: true
    property string customGreeting: ""
    property string avatarPath: ""
    property bool showCapsAndLayout: true
    property bool showWeather: true
    property bool showPowerActions: true

    // Live Howdy hardware/PAM probe (so Settings can show status without locking)
    property bool howdyInstalled: false
    property bool howdyModelPresent: false
    property string howdyStatusText: "Checking…"

    // Parsed hypridle.conf timeouts (display-only overview)
    property var idleListeners: []

    property bool _ignoreNextChange: false

    function setHowdyEnabled(v: bool) { root.howdyEnabled = v; save(); }
    function setCustomGreeting(s: string) { root.customGreeting = s; save(); }
    function setAvatarPath(s: string) { root.avatarPath = s; save(); }
    function setShowCapsAndLayout(v: bool) { root.showCapsAndLayout = v; save(); }
    function setShowWeather(v: bool) { root.showWeather = v; save(); }
    function setShowPowerActions(v: bool) { root.showPowerActions = v; save(); }

    function reset() {
        root.howdyEnabled = true;
        root.customGreeting = "";
        root.avatarPath = "";
        root.showCapsAndLayout = true;
        root.showWeather = true;
        root.showPowerActions = true;
        save();
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
                    if (d.showPowerActions !== undefined) root.showPowerActions = Boolean(d.showPowerActions);
                }
            } catch (e) {}
        }
    }

    FileView {
        id: hypridleFile
        path: (Quickshell.env("HOME") || "") + "/.config/hypr/hypridle.conf"
        printErrors: false
        onLoaded: {
            const raw = text();
            const blocks = raw.split(/listener\s*\{/);
            const out = [];
            for (let i = 1; i < blocks.length; i++) {
                const body = blocks[i].split("}")[0] || "";
                const tm = body.match(/timeout\s*=\s*(\d+)/);
                const onTm = body.match(/on-timeout\s*=\s*([^\n#]+)/);
                if (!tm) continue;
                const secs = parseInt(tm[1]);
                const cmd = onTm ? onTm[1].trim() : "";
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
