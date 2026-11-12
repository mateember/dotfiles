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

    function _runWithPreservedFocus(innerLua: string, movedAddrToOtherWs: string) {
        if (overviewActionProc.running) overviewActionProc.running = false;
        const restore = movedAddrToOtherWs
            ? ("if prev and prev_ws and prev.address:lower() ~= " + luaValue(movedAddrToOtherWs) + " and hl.get_window('address:' .. prev.address) then "
               + "hl.dispatch(hl.dsp.window.focus({ window = 'address:' .. prev.address })) "
               + "elseif prev_ws then hl.dispatch(hl.dsp.focus({ workspace = prev_ws.id })) end")
            : ("if prev and hl.get_window('address:' .. prev.address) then "
               + "hl.dispatch(hl.dsp.window.focus({ window = 'address:' .. prev.address })) "
               + "elseif prev_ws then hl.dispatch(hl.dsp.focus({ workspace = prev_ws.id })) end");
        const script =
            "local prev = hl.get_active_window(); "
            + "local prev_ws = hl.get_active_workspace(); "
            + innerLua + "; "
            + restore;
        overviewActionProc.command = ["hyprctl", "eval", script];
        overviewActionProc.running = true;
    }

    readonly property string _luaColHelper:
        "local function norm(a) a = tostring(a or ''); return a:sub(1,2) == '0x' and a:lower() or ('0x' .. a:lower()) end; "
        + "local function col_index_of(ws_id, target) "
        + "  local wins = hl.get_workspace_windows(ws_id) or {}; "
        + "  local tiled = {}; "
        + "  for _, win in ipairs(wins) do "
        + "    if not win.floating then tiled[#tiled + 1] = win end "
        + "  end; "
        + "  table.sort(tiled, function(a, b) "
        + "    if math.abs(a.at.x - b.at.x) > 24 then return a.at.x < b.at.x end; "
        + "    return a.at.y < b.at.y "
        + "  end); "
        + "  local col_x = nil; local col_idx = -1; local found = nil; "
        + "  for _, win in ipairs(tiled) do "
        + "    if col_x == nil or math.abs(win.at.x - col_x) > 24 then col_x = win.at.x; col_idx = col_idx + 1 end; "
        + "    if norm(win.address) == target then found = col_idx end "
        + "  end; "
        + "  return found, col_idx + 1 "
        + "end; "

    // Moves a window in Overview across workspaces and/or into a scrolling column index.
    function placeWindowInOverview(addr: string, srcWsId: int, dstWsId: int, targetCol: int, expelDir: string) {
        const normAddr = normalizeAddress(addr).toLowerCase();
        if (!root.lua) {
            if (srcWsId !== dstWsId) root.moveWindowToWorkspace(normAddr, dstWsId, false);
            overviewRefreshTimer.restart();
            return;
        }
        const addrLit = luaValue(normAddr);
        const wLit = luaValue("address:" + normAddr);
        if (srcWsId !== dstWsId && (targetCol < 0 || root.layout !== "scrolling")) {
            root.moveWindowToWorkspace(normAddr, dstWsId, false);
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            overviewRefreshTimer.restart();
            return;
        }
        const expelStep = expelDir ? ("hl.dispatch(hl.dsp.layout(" + luaValue("consume_or_expel " + expelDir) + ")); ") : "";
        const moveWsStep = (srcWsId !== dstWsId)
            ? ("hl.dispatch(hl.dsp.window.move({ window = " + wLit + ", workspace = " + dstWsId + ", follow = false })); ")
            : "";
        const inner =
            "local target = " + addrLit + "; "
            + root._luaColHelper
            + moveWsStep
            + "hl.dispatch(hl.dsp.window.focus({ window = " + wLit + " })); "
            + expelStep
            + "local dst_ws = " + dstWsId + "; "
            + "local want = " + targetCol + "; "
            + "for _ = 1, 24 do "
            + "  local cur = col_index_of(dst_ws, target); "
            + "  if not cur or cur == want then break end; "
            + "  hl.dispatch(hl.dsp.layout(cur < want and 'swapcol r' or 'swapcol l')); "
            + "  local nxt = col_index_of(dst_ws, target); "
            + "  if nxt == cur then break end "
            + "end";
        root._runWithPreservedFocus(inner, srcWsId !== dstWsId ? normAddr : "");
    }

    // Reorders a window vertically within its stacked scrolling column.
    function moveWindowInStack(addr: string, delta: int) {
        if (delta === 0) return;
        const normAddr = normalizeAddress(addr).toLowerCase();
        const dir = delta < 0 ? "u" : "d";
        const steps = Math.abs(delta);
        if (!root.lua) {
            for (let i = 0; i < steps; i++) Hyprland.dispatch("movewindow " + dir);
            overviewRefreshTimer.restart();
            return;
        }
        const wLit = luaValue("address:" + normAddr);
        const inner =
            "hl.dispatch(hl.dsp.window.focus({ window = " + wLit + " })); "
            + "for _ = 1, " + steps + " do "
            + "  hl.dispatch(hl.dsp.window.move({ direction = " + luaValue(dir) + " })) "
            + "end";
        root._runWithPreservedFocus(inner, "");
    }

    // Swaps two windows (used in dwindle/master layouts or floating swaps).
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
            "hl.dispatch(hl.dsp.window.focus({ window = " + luaValue("address:" + s) + " })); "
            + "hl.dispatch(hl.dsp.window.swap({ target = " + luaValue("address:" + d) + " }))";
        root._runWithPreservedFocus(inner, "");
    }

    Process {
        id: overviewActionProc
        onExited: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            overviewRefreshTimer.restart();
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
    Timer { id: refreshTimer; interval: 300; onTriggered: root.refreshLayout() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.refreshLayout();
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
