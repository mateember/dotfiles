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

    function focusWindow(addr: string) {
        const w = "address:" + normalizeAddress(addr);
        if (root.lua) Hyprland.dispatch("hl.dsp.focus({ window = " + luaValue(w) + " })");
        else Hyprland.dispatch("focuswindow " + w);
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

    // Scriptable workspace switching: qs -p <root>/shell ipc call workspaces focus 3
    IpcHandler {
        target: "workspaces"
        function focus(selector: string): void { root.focusWorkspace(/^\d+$/.test(selector) ? Number(selector) : selector); }
    }

    // KDE Plasma-style Overview: qs ipc call overview toggle
    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggleOverview(); }
        function open(): void { root.openOverview(); }
        function close(): void { root.closeOverview(); }
    }
}
