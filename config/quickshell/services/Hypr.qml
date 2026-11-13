pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland helpers that work with both config modes.
// In Lua mode (hyprland.lua) Hyprland only accepts Lua dispatchers; in hyprlang mode
// (hyprland.conf) only the old "dispatcher args" strings. Hyprland.usingLua tells which.
// Use these instead of calling Hyprland.dispatch() directly.
Singleton {
    id: root

    readonly property bool lua: Hyprland.usingLua
    property string layout: "dwindle"
    property bool blurEnabled: true
    readonly property var layouts: ["dwindle", "master", "scrolling", "monocle"]

    // Live monitor refresh rates synced with Hyprland (`hyprctl monitors -j`).
    property var monitorRefreshRates: ({})
    property real activeRefreshRate: 120
    property real maxRefreshRate: 120
    readonly property int targetFps: Math.max(24, Math.round(maxRefreshRate > 0 ? maxRefreshRate : 60))

    function refreshRateFor(screenName: string): real {
        if (screenName && typeof root.monitorRefreshRates[screenName] === "number"
                && root.monitorRefreshRates[screenName] > 0) {
            return root.monitorRefreshRates[screenName];
        }
        return root.activeRefreshRate > 0 ? root.activeRefreshRate : 60;
    }

    function fpsFor(screenName: string): int {
        return Math.max(24, Math.round(refreshRateFor(screenName)));
    }
    property bool overviewOpen: false
    property bool overviewSwiping: false
    property real overviewProgress: 0.0
    property real _swipeStartProgress: 0.0

    function openOverview() {
        root.overviewSwiping = false;
        root.overviewOpen = true;
        root.overviewProgress = 1.0;
    }

    function closeOverview() {
        root.overviewSwiping = false;
        root.overviewOpen = false;
        root.overviewProgress = 0.0;
    }

    function toggleOverview() {
        if (root.overviewOpen) root.closeOverview();
        else root.openOverview();
    }

    // Lua string literal for any value (numbers stay numbers).
    function luaValue(v): string {
        return typeof v === "number" ? String(v) : JSON.stringify(String(v));
    }

    function normalizeAddress(addr: string): string {
        const s = String(addr ?? "");
        return s.startsWith("0x") ? s : ("0x" + s);
    }

    // Focus a workspace by selector: 3, "e+1", "m-1", "special:magic", ...
    function focusWorkspace(selector) {
        if (root.lua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + luaValue(selector) + " })");
        else Hyprland.dispatch("workspace " + selector);
    }

    property var _pendingWindow: null

    function focusWindow(addr: string) {
        const w = "address:" + normalizeAddress(addr);
        if (root.lua) {
            const wLit = luaValue(w);
            Quickshell.execDetached([
                "hyprctl", "eval",
                "local w = " + wLit + "; "
                + "local ok = false; "
                + "if hl.dsp.window and hl.dsp.window.focus then "
                + "ok = pcall(function() hl.dispatch(hl.dsp.window.focus({ window = w })) end) "
                + "end; "
                + "if not ok and hl.dsp.focus then "
                + "pcall(function() hl.dispatch(hl.dsp.focus({ window = w })) end) "
                + "end"
            ]);
        } else {
            Hyprland.dispatch("focuswindow " + w);
        }
    }

    function activateWindow(t) {
        if (!t) return;
        const wsId = t.workspace?.id ?? 0;
        const addr = t.address || t.lastIpcObject?.address || "";
        const wl = t.wayland ?? null;
        const needsWsSwitch = wsId > 0 && (Hyprland.focusedWorkspace?.id ?? 0) !== wsId;
        root._pendingWindow = { wsId: wsId, addr: addr, wl: wl, switchWs: needsWsSwitch };
        root.closeOverview();
        if (needsWsSwitch) wsBeforeFocusTimer.restart();
        else winFocusTimer.restart();
    }

    Timer {
        id: wsBeforeFocusTimer
        interval: 30
        onTriggered: {
            const p = root._pendingWindow;
            if (!p) return;
            if (p.wsId > 0) root.focusWorkspace(p.wsId);
            winFocusTimer.restart();
        }
    }

    Timer {
        id: winFocusTimer
        interval: 35
        onTriggered: {
            const p = root._pendingWindow;
            root._pendingWindow = null;
            if (!p) return;
            if (p.wl) p.wl.activate();
            if (p.addr) root.focusWindow(p.addr);
        }
    }

    function closeWindow(addr: string) {
        const w = "address:" + normalizeAddress(addr);
        if (root.lua) Hyprland.dispatch("hl.dsp.window.close({ window = " + luaValue(w) + " })");
        else Hyprland.dispatch("closewindow " + w);
    }

    function moveWindowToWorkspace(addr: string, ws, follow: bool) {
        const w = "address:" + normalizeAddress(addr);
        if (root.lua) {
            Hyprland.dispatch("hl.dsp.window.move({ window = " + luaValue(w)
                + ", workspace = " + luaValue(ws)
                + ", follow = " + (follow ? "true" : "false") + " })");
        } else {
            Hyprland.dispatch((follow ? "movetoworkspace " : "movetoworkspacesilent ") + ws + "," + w);
        }
    }

    // Lua that focuses a window by "address:0x..." selector (hl.dsp.window.focus does not exist).
    function _luaFocus(selectorLit: string): string {
        return "hl.dispatch(hl.dsp.focus({ window = " + selectorLit + " }))";
    }

    // Runs Lua via hyprctl eval, then restores the previously focused window/workspace.
    // When a window left the previous workspace, restore that workspace instead of following it.
    function _runWithPreservedFocus(innerLua: string, movedAddr: string, onDone) {
        const restore =
            "if prev and prev_ws and hl.get_window('address:' .. prev.address) "
            + (movedAddr ? ("and prev.address:lower() ~= " + luaValue(movedAddr) + " ") : "")
            + "then " + root._luaFocus("'address:' .. prev.address") + " "
            + "elseif prev_ws then hl.dispatch(hl.dsp.focus({ workspace = prev_ws.id })) end";
        const script =
            "local prev = hl.get_active_window(); "
            + "local prev_ws = hl.get_active_workspace(); "
            + innerLua + "; "
            + restore;
        root._actionQueue.push({ script: script, onDone: onDone ?? null });
        root._pumpActions();
    }

    property var _actionQueue: []
    property var _currentAction: null
    // True while an Overview drag action runs. The Overview drops its exclusive keyboard grab
    // meanwhile, because Hyprland won't move window focus to another workspace under it and
    // layout messages (swapcol, consume_or_expel) only act on the focused window.
    property bool overviewActionBusy: false

    function _pumpActions() {
        if (overviewActionProc.running || actionStartTimer.running) return;
        if (root._actionQueue.length === 0) {
            root.overviewActionBusy = root._pendingPlacement !== null;
            return;
        }
        root.overviewActionBusy = true;
        actionStartTimer.restart();
    }

    Timer {
        id: actionStartTimer
        interval: 60 // let the layer surface commit keyboardFocus: None first
        onTriggered: {
            if (root._actionQueue.length === 0) { root.overviewActionBusy = false; return; }
            root._currentAction = root._actionQueue.shift();
            overviewActionProc.command = ["hyprctl", "eval", root._currentAction.script];
            overviewActionProc.running = true;
        }
    }

    // Column index of a window among tiled columns of a workspace, from `hyprctl clients -j`.
    function _columnIndexFromClients(clients, wsId: int, addr: string): int {
        const tiled = clients.filter(c => c.workspace?.id === wsId && !c.floating && c.mapped !== false);
        tiled.sort((a, b) => Math.abs(a.at[0] - b.at[0]) > 24 ? a.at[0] - b.at[0] : a.at[1] - b.at[1]);
        let colX = null;
        let col = -1;
        for (const c of tiled) {
            if (colX === null || Math.abs(c.at[0] - colX) > 24) { colX = c.at[0]; col++; }
            if (String(c.address).toLowerCase() === addr) return col;
        }
        return -1;
    }

    property var _pendingPlacement: null

    // Moves a window in Overview across workspaces and/or into a scrolling column index.
    // Phase 1 moves it to the workspace / expels it from its stack; phase 2 re-reads real
    // positions and issues the exact number of swapcol steps.
    function placeWindowInOverview(addr: string, srcWsId: int, dstWsId: int, targetCol: int, expelDir: string) {
        const normAddr = normalizeAddress(addr).toLowerCase();
        if (!root.lua || targetCol < 0 || root.layout !== "scrolling") {
            if (srcWsId !== dstWsId) root.moveWindowToWorkspace(normAddr, dstWsId, false);
            overviewRefreshTimer.restart();
            return;
        }
        const wLit = luaValue("address:" + normAddr);
        let phase1 = "";
        if (srcWsId !== dstWsId)
            phase1 += "hl.dispatch(hl.dsp.window.move({ window = " + wLit + ", workspace = " + dstWsId + ", follow = false })); ";
        if (expelDir)
            phase1 += root._luaFocus(wLit) + "; hl.dispatch(hl.dsp.layout(" + luaValue("consume_or_expel " + expelDir) + ")); ";
        const placement = { addr: normAddr, wsId: dstWsId, want: targetCol, moved: srcWsId !== dstWsId };
        if (phase1) {
            root._runWithPreservedFocus(phase1 + "local _ = 0", placement.moved ? normAddr : "", () => root._queryPlacement(placement));
        } else {
            root._queryPlacement(placement);
        }
    }

    function _queryPlacement(placement) {
        root._pendingPlacement = placement;
        clientsProc.running = false;
        clientsProc.running = true;
    }

    function _finishPlacement(clients) {
        const p = root._pendingPlacement;
        root._pendingPlacement = null;
        if (!p) return;
        const cur = root._columnIndexFromClients(clients, p.wsId, p.addr);
        if (cur < 0 || cur === p.want) { overviewRefreshTimer.restart(); root._pumpActions(); return; }
        const steps = Math.abs(p.want - cur);
        const dir = p.want > cur ? "swapcol r" : "swapcol l";
        const inner =
            root._luaFocus(luaValue("address:" + p.addr)) + "; "
            + "for _ = 1, " + steps + " do hl.dispatch(hl.dsp.layout(" + luaValue(dir) + ")) end";
        root._runWithPreservedFocus(inner, p.moved ? p.addr : "", null);
    }

    // Reorders a window vertically within its stacked scrolling column.
    function moveWindowInStack(addr: string, delta: int) {
        if (delta === 0) return;
        const normAddr = normalizeAddress(addr).toLowerCase();
        const dir = delta < 0 ? "u" : "d";
        const steps = Math.abs(delta);
        if (!root.lua) {
            Hyprland.dispatch("focuswindow address:" + normAddr);
            for (let i = 0; i < steps; i++) Hyprland.dispatch("movewindow " + dir);
            overviewRefreshTimer.restart();
            return;
        }
        const inner =
            root._luaFocus(luaValue("address:" + normAddr)) + "; "
            + "for _ = 1, " + steps + " do "
            + "  hl.dispatch(hl.dsp.window.move({ direction = " + luaValue(dir) + " })) "
            + "end";
        root._runWithPreservedFocus(inner, "", null);
    }

    // Swaps two windows (used in dwindle/master layouts).
    function swapWindows(srcAddr: string, dstAddr: string) {
        const s = normalizeAddress(srcAddr).toLowerCase();
        const d = normalizeAddress(dstAddr).toLowerCase();
        if (s === d) return;
        if (!root.lua) {
            Hyprland.dispatch("focuswindow address:" + s);
            Hyprland.dispatch("swapwindow address:" + d);
            overviewRefreshTimer.restart();
            return;
        }
        const inner =
            root._luaFocus(luaValue("address:" + s)) + "; "
            + "hl.dispatch(hl.dsp.window.swap({ target = " + luaValue("address:" + d) + " }))";
        root._runWithPreservedFocus(inner, "", null);
    }

    Process {
        id: overviewActionProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Hypr overview action:", text.trim())
        }
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() && text.trim() !== "ok") console.warn("Hypr overview action:", text.trim())
        }
        onExited: {
            const done = root._currentAction?.onDone ?? null;
            root._currentAction = null;
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            overviewRefreshTimer.restart();
            if (done) done();
            root._pumpActions();
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients = [];
                try { clients = JSON.parse(text); } catch (e) {}
                root._finishPlacement(clients);
            }
        }
    }

    Timer {
        id: overviewRefreshTimer
        interval: 80
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    function toggleSpecial(name: string) {
        if (root.lua) Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + luaValue(name) + ")");
        else Hyprland.dispatch("togglespecialworkspace " + name);
    }

    // Send a layout message, e.g. "togglesplit".
    function layoutMsg(msg: string) {
        if (root.lua) Hyprland.dispatch("hl.dsp.layout(" + luaValue(msg) + ")");
        else Hyprland.dispatch("layoutmsg " + msg);
    }

    // Under UWSM (the NixOS "Hyprland (uwsm-managed)" session) stop it cleanly; otherwise exit directly.
    function exit() {
        const direct = root.lua ? "hyprctl dispatch 'hl.dsp.exit()'" : "hyprctl dispatch exit";
        Quickshell.execDetached(["sh", "-c", "uwsm check is-active && uwsm stop || " + direct]);
    }

    // general.layout is global. Changing it at runtime lasts until the config is reloaded.
    function setLayout(name: string) {
        if (root.lua) Quickshell.execDetached(["hyprctl", "eval", "hl.config({ general = { layout = " + luaValue(name) + " } })"]);
        else Quickshell.execDetached(["hyprctl", "keyword", "general:layout", name]);
        root.layout = name;
        refreshTimer.restart();
    }
    // Bar click: scrolling (niri style, the default) ↔ dwindle.
    function toggleLayout() {
        setLayout(root.layout === "scrolling" ? "dwindle" : "scrolling");
    }
    function refreshLayout() {
        getLayout.running = true;
        getBlur.running = true;
        refreshMonitors();
    }

    function refreshMonitors() {
        getMonitors.running = false;
        getMonitors.running = true;
    }

    function scheduleMonitorsRefresh() {
        monitorsRefreshTimer.restart();
    }

    // Session-only runtime blur toggle (does not write config/state, so logout/reboot resets it).
    function setBlur(on: bool) {
        const val = Boolean(on);
        if (root.lua) {
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.config({ decoration = { blur = { enabled = " + (val ? "true" : "false") + " } } })"
            ]);
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:enabled", val ? "true" : "false"]);
        }
        root.blurEnabled = val;
        refreshTimer.restart();
    }

    function toggleBlur() {
        setBlur(!root.blurEnabled);
    }

    Process {
        id: getLayout
        command: ["hyprctl", "getoption", "general:layout", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.layout = JSON.parse(text).str; } catch (e) {}
            }
        }
    }
    Process {
        id: getBlur
        command: ["hyprctl", "getoption", "decoration:blur:enabled", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (typeof j.bool === "boolean") root.blurEnabled = j.bool;
                    else if (typeof j.int === "number") root.blurEnabled = j.int !== 0;
                } catch (e) {}
            }
        }
    }
    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text);
                    if (!Array.isArray(arr) || arr.length === 0) return;
                    const map = {};
                    let maxRate = 0;
                    let focusedRate = 0;
                    for (const m of arr) {
                        if (!m || m.disabled) continue;
                        const r = Number(m.refreshRate);
                        if (!isFinite(r) || r <= 0) continue;
                        if (m.name) map[m.name] = r;
                        if (r > maxRate) maxRate = r;
                        if (m.focused) focusedRate = r;
                    }
                    root.monitorRefreshRates = map;
                    if (maxRate > 0) root.maxRefreshRate = maxRate;
                    if (focusedRate > 0) root.activeRefreshRate = focusedRate;
                    else if (maxRate > 0) root.activeRefreshRate = maxRate;
                } catch (e) {}
            }
        }
    }
    Timer { id: monitorsRefreshTimer; interval: 180; onTriggered: root.refreshMonitors() }
    Timer { id: refreshTimer; interval: 300; onTriggered: root.refreshLayout() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.refreshLayout();
            else if (event.name === "monitoradded" || event.name === "monitoraddedv2"
                  || event.name === "monitorremoved" || event.name === "monitorremovedv2"
                  || event.name === "focusedmon" || event.name === "focusedmonv2") {
                root.scheduleMonitorsRefresh();
            }
            if (event.name === "custom" && event.data.startsWith("hcs_overview:")) {
                const parts = event.data.split(":");
                const phase = parts[1];
                const arg = parts[2] ?? "0";
                const swipeDist = 180.0;
                if (phase === "start") {
                    root._swipeStartProgress = root.overviewOpen ? 1.0 : 0.0;
                    root.overviewSwiping = true;
                    const dy = parseFloat(arg) || 0;
                    root.overviewProgress = Math.max(0.0, Math.min(1.0, root._swipeStartProgress + dy / swipeDist));
                } else if (phase === "update") {
                    const dy = parseFloat(arg) || 0;
                    root.overviewProgress = Math.max(0.0, Math.min(1.0, root._swipeStartProgress + dy / swipeDist));
                } else if (phase === "finish") {
                    root.overviewSwiping = false;
                    if (arg === "cancel") {
                        root.overviewProgress = root.overviewOpen ? 1.0 : 0.0;
                    } else {
                        const dy = parseFloat(arg) || 0;
                        if (dy > 35) root.openOverview();
                        else if (dy < -35) root.closeOverview();
                        else if (root.overviewProgress >= 0.5) root.openOverview();
                        else root.closeOverview();
                    }
                }
            }
        }
    }

    Component.onCompleted: refreshLayout()

    // qs ipc call workspaces focus 3
    IpcHandler {
        target: "workspaces"
        function focus(selector: string): void { root.focusWorkspace(/^\d+$/.test(selector) ? Number(selector) : selector); }
    }

    // qs ipc call overview toggle
    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggleOverview(); }
        function open(): void { root.openOverview(); }
        function close(): void { root.closeOverview(); }
    }
}
