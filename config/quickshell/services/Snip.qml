pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// COSMIC-style interactive fullscreen screenshot service:
// freezes all monitors at native DPI, lets you freely select/resize/adjust
// across Rectangle, Window, or Screen modes, and commits via Copy / Save / Satty.
Singleton {
    id: root

    property bool active: false
    property bool capturing: false
    property string mode: "region"          // "region" | "window" | "output"
    property string defaultAction: "copy"   // "copy" | "save" | "annotate"
    property string sessionDir: ""
    property string activeScreen: ""

    property var monitors: ({})             // screenName -> monitor object
    property var windowsByMonitor: ({})     // screenName -> window list (topmost first)

    // Active selection rectangle in activeScreen logical coordinates.
    property bool hasSelection: false
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property string selectedTitle: ""
    property var initialHoveredWindow: null

    readonly property string scriptPath: Quickshell.shellPath("scripts/capture.sh")

    property string _pendingMode: "region"
    property string _pendingAction: "copy"
    property string _pendingSession: ""
    property string _freezeBuf: ""
    property bool _freezeExited: false
    property bool _freezeStreamDone: false

    function start(initialMode: string, preferredAction: string, delaySec: int, waitForShell: bool) {
        const m = (initialMode === "window" || initialMode === "output") ? initialMode : "region";
        if (root.active) {
            root.setMode(m);
            return;
        }
        if (root.capturing) return;

        const hadShellUi = Boolean(waitForShell)
            || Popups.current !== ""
            || QuickSettingsState.open
            || Recorder.overlayOpen
            || Hypr.overviewOpen;

        Popups.hide();
        QuickSettingsState.hide();
        Recorder.hideOverlay();
        Hypr.closeOverview();
        WidgetHistory.clear();

        root._pendingMode = m;
        root._pendingAction = (preferredAction === "save" || preferredAction === "annotate") ? preferredAction : "copy";

        const totalWait = (delaySec > 0 ? delaySec * 1000 : 0) + (hadShellUi ? 220 : 0);
        if (totalWait > 0) {
            waitTimer.interval = totalWait;
            waitTimer.restart();
        } else {
            root._beginFreeze();
        }
    }

    function _beginFreeze() {
        if (root.capturing || root.active) return;
        root.capturing = true;
        root._freezeBuf = "";
        root._freezeExited = false;
        root._freezeStreamDone = false;
        root._pendingSession = "/tmp/hcs_snip_" + Date.now();
        freezeProc.command = ["bash", root.scriptPath, "freeze", root._pendingSession];
        freezeProc.running = true;
    }

    function _maybeFinishFreeze() {
        if (!root._freezeExited || !root._freezeStreamDone) return;
        root.capturing = false;

        let data = null;
        try {
            data = JSON.parse(root._freezeBuf.trim());
        } catch (e) {
            data = null;
        }
        if (!data || !data.monitors || data.monitors.length === 0) {
            if (root._pendingSession)
                Quickshell.execDetached(["rm", "-rf", root._pendingSession]);
            root._pendingSession = "";
            return;
        }

        const monMap = {};
        const winMap = {};
        for (const m of data.monitors) {
            monMap[m.name] = m;
            winMap[m.name] = [];
        }
        if (data.windows) {
            for (const w of data.windows) {
                if (winMap[w.monitorName])
                    winMap[w.monitorName].push(w);
            }
        }

        let focusMon = data.focusedMonitor || data.monitors[0].name;
        const cur = data.cursor;
        if (cur && typeof cur.x === "number" && typeof cur.y === "number") {
            for (const m of data.monitors) {
                if (cur.x >= m.x && cur.x < m.x + m.logW && cur.y >= m.y && cur.y < m.y + m.logH) {
                    focusMon = m.name;
                    break;
                }
            }
        }

        root.sessionDir = data.sessionDir || root._pendingSession;
        root.monitors = monMap;
        root.windowsByMonitor = winMap;
        root.activeScreen = focusMon;
        root.mode = root._pendingMode;
        root.defaultAction = root._pendingAction;
        root.initialHoveredWindow = null;

        if (root.mode === "output") {
            root.selectScreenFull(focusMon);
        } else {
            root.clearSelection();
            if (root.mode === "window" && cur && monMap[focusMon]) {
                const m = monMap[focusMon];
                root.initialHoveredWindow = root.windowAt(focusMon, cur.x - m.x, cur.y - m.y);
            }
        }

        root.active = true;
    }

    function setMode(newMode: string) {
        if (newMode !== "region" && newMode !== "window" && newMode !== "output") return;
        root.mode = newMode;
        if (newMode === "output") {
            root.selectScreenFull(root.activeScreen);
        } else if (newMode === "window") {
            root.clearSelection();
        }
        // Switching to "region" keeps any existing selection box so you can resize/expand it freely.
    }

    function clearSelection() {
        root.hasSelection = false;
        root.selX = 0;
        root.selY = 0;
        root.selW = 0;
        root.selH = 0;
        root.selectedTitle = "";
    }

    function selectScreenFull(screenName: string) {
        const mon = root.monitors[screenName];
        if (!mon) return;
        root.activeScreen = screenName;
        root.selX = 0;
        root.selY = 0;
        root.selW = mon.logW;
        root.selH = mon.logH;
        root.hasSelection = true;
        root.selectedTitle = mon.name;
    }

    function setSelection(screenName: string, x: real, y: real, w: real, h: real, title: string) {
        const mon = root.monitors[screenName];
        if (!mon) return;
        const cx = Math.max(0, Math.min(mon.logW, x));
        const cy = Math.max(0, Math.min(mon.logH, y));
        const cw = Math.max(0, Math.min(mon.logW - cx, w));
        const ch = Math.max(0, Math.min(mon.logH - cy, h));
        root.activeScreen = screenName;
        root.selX = cx;
        root.selY = cy;
        root.selW = cw;
        root.selH = ch;
        root.hasSelection = (cw >= 4 && ch >= 4);
        root.selectedTitle = title || "";
    }

    function windowAt(screenName: string, lx: real, ly: real): var {
        const list = root.windowsByMonitor[screenName];
        if (!list) return null;
        for (const w of list) {
            if (lx >= w.x && lx <= w.x + w.w && ly >= w.y && ly <= w.y + w.h)
                return w;
        }
        return null;
    }

    function commit(action: string) {
        if (!root.active) return;
        const act = (action === "save" || action === "annotate") ? action : "copy";
        const scr = root.activeScreen;
        const mon = root.monitors[scr];
        if (!mon) {
            root.cancel();
            return;
        }

        let bx = 0, by = 0, bw = mon.logW, bh = mon.logH;
        if (root.hasSelection && root.selW >= 4 && root.selH >= 4) {
            bx = root.selX;
            by = root.selY;
            bw = root.selW;
            bh = root.selH;
        }

        const scale = mon.scale > 0 ? mon.scale : 1;
        const px = Math.max(0, Math.min(mon.physW - 1, Math.round(bx * scale)));
        const py = Math.max(0, Math.min(mon.physH - 1, Math.round(by * scale)));
        const pw = Math.max(1, Math.min(mon.physW - px, Math.round(bw * scale)));
        const ph = Math.max(1, Math.min(mon.physH - py, Math.round(bh * scale)));
        const isFull = (px === 0 && py === 0 && pw === mon.physW && ph === mon.physH) ? "1" : "0";

        const dir = root.sessionDir;
        const src = dir + "/" + scr + ".png";

        root.active = false;
        root.clearSelection();
        root.initialHoveredWindow = null;
        root.sessionDir = "";

        Quickshell.execDetached([
            "bash", root.scriptPath, "commit",
            src, String(px), String(py), String(pw), String(ph), isFull, act, dir
        ]);
    }

    function cancel() {
        const dir = root.sessionDir;
        root.active = false;
        root.clearSelection();
        root.initialHoveredWindow = null;
        root.sessionDir = "";
        if (dir) Quickshell.execDetached(["rm", "-rf", dir]);
    }

    Timer {
        id: waitTimer
        repeat: false
        onTriggered: root._beginFreeze()
    }

    Process {
        id: freezeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._freezeBuf = this.text;
                root._freezeStreamDone = true;
                root._maybeFinishFreeze();
            }
        }
        onExited: {
            root._freezeExited = true;
            root._maybeFinishFreeze();
        }
    }
}
