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
    readonly property var layouts: ["dwindle", "master", "scrolling", "monocle"]

    // Lua string literal for any value (numbers stay numbers).
    function luaValue(v): string {
        return typeof v === "number" ? String(v) : JSON.stringify(String(v));
    }

    // Focus a workspace by selector: 3, "e+1", "m-1", "special:magic", ...
    function focusWorkspace(selector) {
        if (root.lua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + luaValue(selector) + " })");
        else Hyprland.dispatch("workspace " + selector);
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
    Timer { id: refreshTimer; interval: 300; onTriggered: root.refreshLayout() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.refreshLayout();
        }
    }

    Component.onCompleted: refreshLayout()

    // Scriptable workspace switching: qs -p <root>/shell ipc call workspaces focus 3
    IpcHandler {
        target: "workspaces"
        function focus(selector: string): void { root.focusWorkspace(/^\d+$/.test(selector) ? Number(selector) : selector); }
    }
}
