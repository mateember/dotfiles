pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// Live Hyprland settings reader/writer with persistent Lua overrides.
// Only settings explicitly modified in HCS Settings are written to
// `~/.local/state/quickshell/hypr-overrides.lua` (sourced safely at the end of
// `config/hypr/hyprland.lua`), so personal edits in `conf/*.lua` stay untouched.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string stateFile: stateDir + "/hypr-settings.json"
    readonly property string luaOverrideFile: stateDir + "/hypr-overrides.lua"

    // ---- Connected monitors from `hyprctl monitors all -j` ----
    property var monitors: []
    property bool monitorsLoading: false

    // Monitor safety revert countdown (seconds remaining; 0 = none pending)
    property int revertCountdown: 0
    property var _backupMonitors: null

    // ---- Sunshine / headless virtual monitor ----
    readonly property bool sunshineActive: monitors.some(m => m.name === "REMOTE" && !m.disabled)

    // ---- Keyboard layout state ----
    property string activeKeyboardName: ""
    property string activeKeymap: ""
    property var kbLayouts: ["hu"]
    property string kbOptions: "fkeys:basic_13-24"
    property bool capsLockOn: false
    property bool numLockOn: false
    property bool capsOsdEnabled: true

    // ---- Editable Hyprland visual & input state (loaded from live Hyprland + overrides) ----
    property int gapsIn: 3
    property int gapsOut: 7
    property int borderSize: 2
    property int rounding: 5
    property real inactiveOpacity: 0.75
    property bool blurEnabled: true
    property int blurSize: 3
    property int blurPasses: 1
    property bool animationsEnabled: true

    property real mouseSensitivity: -0.35
    property string mouseAccelProfile: "flat"    // "flat" | "adaptive"
    property bool mouseNaturalScroll: false
    property string touchpadName: "ftcs0038:00-2808:0105-touchpad"
    property real touchpadSensitivity: 0.03
    property bool touchpadNaturalScroll: true
    property bool touchpadTapToClick: true

    // Overrides map: only keys present here are emitted into hypr-overrides.lua.
    property var overrides: ({})

    // ---- Parsed keybindings (from hyprctl binds -j + Lua comments) ----
    property var keybinds: []
    property bool keybindsLoading: false

    signal layoutSwitched(string layoutName)
    signal lockKeyChanged(string keyName, bool active)

    // ---- Helpers ----

    function luaStr(s): string {
        const str = String(s ?? "");
        let out = '"';
        for (let i = 0; i < str.length; i++) {
            const c = str.charCodeAt(i);
            if (c === 0x5c) out += "\\\\";
            else if (c === 0x22) out += '\\"';
            else if (c === 0x0a) out += "\\n";
            else if (c === 0x0d) out += "\\r";
            else if (c === 0x09) out += "\\t";
            else if (c < 0x20 || c === 0x7f) out += "\\" + String(c).padStart(3, "0");
            else out += str.charAt(i);
        }
        return out + '"';
    }

    function luaNum(v, fallback: real, decimals: int): string {
        const n = Number(v);
        const safe = Number.isFinite(n) ? n : fallback;
        return decimals >= 0 ? safe.toFixed(decimals) : String(safe);
    }

    function hexToHyprRgba(hex: string, alphaHex: string): string {
        let h = String(hex || "").trim().replace(/^#/, "");
        if (h.length === 8) h = h.slice(2); // strip Qt #AARRGGBB alpha
        if (h.length !== 6) h = "ffad00";
        return "rgba(" + h.toLowerCase() + (alphaHex || "ee") + ")";
    }

    function refreshMonitors() {
        if (!monProc.running) {
            root.monitorsLoading = true;
            monProc.running = true;
        }
    }

    function refreshDevices() {
        if (!devProc.running) devProc.running = true;
    }

    function refreshLiveOptions() {
        if (!optProc.running) optProc.running = true;
    }

    function refreshKeybinds() {
        if (!bindsProc.running) {
            root.keybindsLoading = true;
            bindsProc.running = true;
        }
    }

    function refreshAll() {
        refreshMonitors();
        refreshDevices();
        refreshLiveOptions();
    }

    // ---- Apply & Persist Overrides ----

    function setOverride(key: string, val) {
        const next = Object.assign({}, root.overrides);
        next[key] = val;
        root.overrides = next;
        scheduleSave();
    }

    function clearOverride(key: string) {
        if (!(key in root.overrides)) return;
        const next = Object.assign({}, root.overrides);
        delete next[key];
        root.overrides = next;
        scheduleSave();
    }

    function _reloadAfterSave(refreshDevs: bool, refreshMons: bool) {
        saveNow();
        reloadProc.wantDevs = refreshDevs;
        reloadProc.wantMons = refreshMons;
        // Wait briefly for atomic FileView writes to land before `hyprctl reload`.
        reloadDelay.restart();
    }

    Timer {
        id: reloadDelay
        interval: 80
        onTriggered: {
            reloadProc.running = false;
            reloadProc.running = true;
        }
    }

    Process {
        id: reloadProc
        property bool wantDevs: false
        property bool wantMons: false
        command: ["timeout", "5", "hyprctl", "reload"]
        onExited: {
            root.refreshLiveOptions();
            if (wantDevs) root.refreshDevices();
            if (wantMons) root.refreshMonitors();
        }
    }

    function resetVisualOverrides() {
        const keys = [
            "gaps_in", "gaps_out", "border_size", "rounding",
            "inactive_opacity", "blur_enabled", "blur_size", "blur_passes",
            "animations_enabled", "layout", "active_border", "inactive_border"
        ];
        const next = Object.assign({}, root.overrides);
        for (const k of keys) delete next[k];
        root.overrides = next;
        _reloadAfterSave(false, false);
    }

    function resetInputOverrides() {
        const keys = [
            "mouse_sensitivity", "mouse_accel", "mouse_natural_scroll",
            "touchpad_sensitivity", "touchpad_natural_scroll", "touchpad_tap_to_click",
            "kb_layout", "kb_options"
        ];
        const next = Object.assign({}, root.overrides);
        for (const k of keys) delete next[k];
        root.overrides = next;
        _reloadAfterSave(true, false);
    }

    function hyprSet(luaExpr: string, k: string, v: string) {
        if (Hypr.lua) {
            Quickshell.execDetached(["hyprctl", "eval", luaExpr]);
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", k, v]);
        }
    }

    function setGapsIn(v: int) {
        root.gapsIn = Math.max(0, Math.min(32, v));
        hyprSet(`hl.config({ general = { gaps_in = ${root.gapsIn} } })`, "general:gaps_in", String(root.gapsIn));
        setOverride("gaps_in", root.gapsIn);
    }

    function setGapsOut(v: int) {
        root.gapsOut = Math.max(0, Math.min(48, v));
        hyprSet(`hl.config({ general = { gaps_out = ${root.gapsOut} } })`, "general:gaps_out", String(root.gapsOut));
        setOverride("gaps_out", root.gapsOut);
    }

    function setBorderSize(v: int) {
        root.borderSize = Math.max(0, Math.min(8, v));
        hyprSet(`hl.config({ general = { border_size = ${root.borderSize} } })`, "general:border_size", String(root.borderSize));
        setOverride("border_size", root.borderSize);
    }

    function setRounding(v: int) {
        root.rounding = Math.max(0, Math.min(24, v));
        hyprSet(`hl.config({ decoration = { rounding = ${root.rounding} } })`, "decoration:rounding", String(root.rounding));
        setOverride("rounding", root.rounding);
    }

    function setInactiveOpacity(v: real) {
        root.inactiveOpacity = Math.round(Math.max(0.35, Math.min(1.0, v)) * 100) / 100;
        const f = root.inactiveOpacity.toFixed(2);
        hyprSet(`hl.config({ decoration = { inactive_opacity = ${f} } })`, "decoration:inactive_opacity", f);
        setOverride("inactive_opacity", root.inactiveOpacity);
    }

    function setBlurEnabled(on: bool) {
        root.blurEnabled = on;
        Hypr.blurEnabled = on;
        const b = on ? "true" : "false";
        hyprSet(`hl.config({ decoration = { blur = { enabled = ${b} } } })`, "decoration:blur:enabled", b);
        setOverride("blur_enabled", on);
    }

    function setBlurSize(v: int) {
        root.blurSize = Math.max(1, Math.min(16, v));
        hyprSet(`hl.config({ decoration = { blur = { size = ${root.blurSize} } } })`, "decoration:blur:size", String(root.blurSize));
        setOverride("blur_size", root.blurSize);
    }

    function setBlurPasses(v: int) {
        root.blurPasses = Math.max(1, Math.min(5, v));
        hyprSet(`hl.config({ decoration = { blur = { passes = ${root.blurPasses} } } })`, "decoration:blur:passes", String(root.blurPasses));
        setOverride("blur_passes", root.blurPasses);
    }

    function setAnimationsEnabled(on: bool) {
        root.animationsEnabled = on;
        const b = on ? "true" : "false";
        hyprSet(`hl.config({ animations = { enabled = ${b} } })`, "animations:enabled", b);
        setOverride("animations_enabled", on);
    }

    function setDesktopLayout(name: string) {
        Hypr.setLayout(name);
        setOverride("layout", name);
    }

    function applyThemeBorders(accentHex: string, secondaryHex: string, inactiveHex: string, roundingVal: int) {
        const act1 = hexToHyprRgba(accentHex, "ee");
        const act2 = hexToHyprRgba(secondaryHex, "dd");
        const inact = hexToHyprRgba(inactiveHex, "aa");
        hyprSet(
            `hl.config({ general = { col = { active_border = { colors = { ${luaStr(act1)}, ${luaStr(act2)} }, angle = 45 }, inactive_border = ${luaStr(inact)} } } })`,
            "general:col.active_border",
            act1 + " " + act2 + " 45deg"
        );
        if (!Hypr.lua) hyprSet("", "general:col.inactive_border", inact);
        setOverride("active_border", [act1, act2]);
        setOverride("inactive_border", inact);
        if (roundingVal >= 0) {
            setRounding(roundingVal);
        }
    }

    // ---- Input controls ----

    function setMouseSensitivity(v: real) {
        root.mouseSensitivity = Math.round(Math.max(-1.0, Math.min(1.0, v)) * 100) / 100;
        const f = root.mouseSensitivity.toFixed(2);
        hyprSet(`hl.config({ input = { sensitivity = ${f} } })`, "input:sensitivity", f);
        setOverride("mouse_sensitivity", root.mouseSensitivity);
    }

    function setMouseAccelProfile(p: string) {
        root.mouseAccelProfile = (p === "adaptive") ? "adaptive" : "flat";
        hyprSet(`hl.config({ input = { accel_profile = ${luaStr(root.mouseAccelProfile)} } })`, "input:accel_profile", root.mouseAccelProfile);
        setOverride("mouse_accel", root.mouseAccelProfile);
    }

    function setMouseNaturalScroll(on: bool) {
        root.mouseNaturalScroll = on;
        const b = on ? "true" : "false";
        hyprSet(`hl.config({ input = { natural_scroll = ${b} } })`, "input:natural_scroll", b);
        setOverride("mouse_natural_scroll", on);
    }

    function setTouchpadSensitivity(v: real) {
        root.touchpadSensitivity = Math.round(Math.max(-1.0, Math.min(1.0, v)) * 100) / 100;
        const f = root.touchpadSensitivity.toFixed(2);
        if (root.touchpadName)
            hyprSet(`hl.device({ name = ${luaStr(root.touchpadName)}, sensitivity = ${f} })`, "device[" + root.touchpadName + "]:sensitivity", f);
        setOverride("touchpad_sensitivity", root.touchpadSensitivity);
    }

    function setTouchpadNaturalScroll(on: bool) {
        root.touchpadNaturalScroll = on;
        const b = on ? "true" : "false";
        hyprSet(`hl.config({ input = { touchpad = { natural_scroll = ${b} } } })`, "input:touchpad:natural_scroll", b);
        if (root.touchpadName)
            hyprSet(`hl.device({ name = ${luaStr(root.touchpadName)}, natural_scroll = ${b} })`, "device[" + root.touchpadName + "]:natural_scroll", b);
        setOverride("touchpad_natural_scroll", on);
    }

    function setTouchpadTapToClick(on: bool) {
        root.touchpadTapToClick = on;
        const b = on ? "true" : "false";
        hyprSet(`hl.config({ input = { touchpad = { ["tap-to-click"] = ${b} } } })`, "input:touchpad:tap-to-click", b);
        setOverride("touchpad_tap_to_click", on);
    }

    function setKeyboardLayouts(layoutsArr) {
        const cleaned = layoutsArr.map(s => String(s).trim().toLowerCase()).filter(Boolean);
        if (cleaned.length === 0) return;
        root.kbLayouts = cleaned;
        const csv = cleaned.join(",");
        hyprSet(`hl.config({ input = { kb_layout = ${luaStr(csv)} } })`, "input:kb_layout", csv);
        setOverride("kb_layout", csv);
        Qt.callLater(() => refreshDevices());
    }

    function toggleKeyboardLayout(code: string) {
        const c = code.trim().toLowerCase();
        const cur = root.kbLayouts.slice();
        const idx = cur.indexOf(c);
        if (idx >= 0) {
            if (cur.length <= 1) return; // keep at least one layout
            cur.splice(idx, 1);
        } else {
            cur.push(c);
        }
        setKeyboardLayouts(cur);
    }

    function setKeyboardToggleOption(grpOpt: string) {
        // Preserve fkeys:basic_13-24 while swapping grp:* option.
        const parts = root.kbOptions.split(",").map(s => s.trim()).filter(s => s && !s.startsWith("grp:"));
        if (grpOpt) parts.push(grpOpt);
        root.kbOptions = parts.join(",");
        hyprSet(`hl.config({ input = { kb_options = ${luaStr(root.kbOptions)} } })`, "input:kb_options", root.kbOptions);
        setOverride("kb_options", root.kbOptions);
    }

    function currentKbToggleOption(): string {
        const parts = root.kbOptions.split(",").map(s => s.trim());
        for (const p of parts) if (p.startsWith("grp:")) return p;
        return "";
    }

    function switchNextKeyboardLayout() {
        const target = root.activeKeyboardName || "current";
        Quickshell.execDetached(["hyprctl", "switchxkblayout", target, "next"]);
        devRefreshDelay.restart();
    }

    function setCapsOsdEnabled(on: bool) {
        root.capsOsdEnabled = on;
        scheduleSave();
    }

    // ---- Monitor Arrangement & Apply with 15s Safety Revert ----

    function monitorSpecToLua(m): string {
        const out = m.description ? ("desc:" + m.description) : m.name;
        if (m.disabled) {
            return `hl.monitor({ output = ${luaStr(out)}, disabled = true })`;
        }
        const mx = Number.isFinite(Number(m.x)) ? Math.round(Number(m.x)) : 0;
        const my = Number.isFinite(Number(m.y)) ? Math.round(Number(m.y)) : 0;
        const sc = Number(m.scale);
        const scaleStr = (Number.isFinite(sc) && sc > 0) ? sc.toFixed(2).replace(/\.00$/, "") : "1";
        const parts = [
            `output = ${luaStr(out)}`,
            `mode = ${luaStr(m.mode || "preferred")}`,
            `position = ${luaStr(mx + "x" + my)}`,
            `scale = ${scaleStr}`
        ];
        if (m.vrr !== undefined && m.vrr !== null && Number.isFinite(Number(m.vrr))) parts.push(`vrr = ${Math.round(Number(m.vrr))}`);
        if (m.transform !== undefined && Number.isFinite(Number(m.transform)) && Number(m.transform) > 0) parts.push(`transform = ${Math.round(Number(m.transform))}`);
        if (m.mirror && m.mirror !== "") parts.push(`mirror = ${luaStr(m.mirror)}`);
        return `hl.monitor({ ${parts.join(", ")} })`;
    }

    function applyMonitorPlan(planList, withSafetyRevert: bool) {
        if (!Array.isArray(planList) || planList.length === 0) return;

        if (withSafetyRevert) {
            root._backupMonitors = root.monitors.map(m => ({
                name: m.name,
                description: m.description,
                disabled: Boolean(m.disabled),
                mode: `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}`,
                x: m.x,
                y: m.y,
                scale: m.scale,
                vrr: m.vrr ? 1 : 0,
                transform: m.transform || 0,
                mirror: ""
            }));
        }

        const evalLines = planList.map(m => monitorSpecToLua(m)).join("; ");
        Quickshell.execDetached(["hyprctl", "eval", evalLines]);

        // Persist immediately; if user reverts we restore the backup.
        setOverride("monitors", planList);
        Hypr.scheduleMonitorsRefresh();
        monRefreshDelay.restart();

        if (withSafetyRevert) {
            root.revertCountdown = 15;
            revertTimer.restart();
        }
    }

    function confirmMonitors() {
        revertTimer.stop();
        root.revertCountdown = 0;
        root._backupMonitors = null;
    }

    function revertMonitors() {
        revertTimer.stop();
        root.revertCountdown = 0;
        if (!root._backupMonitors) return;
        const backup = root._backupMonitors;
        root._backupMonitors = null;
        applyMonitorPlan(backup, false);
    }

    function clearMonitorOverrides() {
        confirmMonitors();
        const next = Object.assign({}, root.overrides);
        delete next.monitors;
        root.overrides = next;
        _reloadAfterSave(false, true);
    }

    // ---- Sunshine Headless Virtual Display ----

    function toggleSunshineVirtualDisplay() {
        if (root.sunshineActive) {
            Quickshell.execDetached(["hyprctl", "output", "remove", "REMOTE"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "hyprctl output create headless REMOTE && sleep 0.25 && hyprctl eval 'hl.monitor({ output = \"REMOTE\", mode = \"1920x1080@60\", position = \"auto\", scale = 1 })'"]);
        }
        monRefreshDelay.restart();
    }

    // ---- Generate ~/.local/state/quickshell/hypr-overrides.lua ----

    function generateLuaOverrides(): string {
        const o = root.overrides || {};
        const lines = [
            "-- Auto-generated by HCS Settings (Quickshell). Do not hand-edit.",
            "-- Delete this file or click Reset in Settings to restore defaults."
        ];

        const cfg = [];
        // general
        const gen = [];
        if (o.gaps_in !== undefined) gen.push(`        gaps_in = ${luaNum(o.gaps_in, 3, 0)},`);
        if (o.gaps_out !== undefined) gen.push(`        gaps_out = ${luaNum(o.gaps_out, 6, 0)},`);
        if (o.border_size !== undefined) gen.push(`        border_size = ${luaNum(o.border_size, 2, 0)},`);
        if (o.layout !== undefined) gen.push(`        layout = ${luaStr(o.layout)},`);
        if (o.active_border !== undefined || o.inactive_border !== undefined) {
            gen.push("        col = {");
            if (Array.isArray(o.active_border) && o.active_border.length >= 2)
                gen.push(`            active_border = { colors = { ${luaStr(o.active_border[0])}, ${luaStr(o.active_border[1])} }, angle = 45 },`);
            if (o.inactive_border !== undefined)
                gen.push(`            inactive_border = ${luaStr(o.inactive_border)},`);
            gen.push("        },");
        }
        if (gen.length > 0) cfg.push("    general = {\n" + gen.join("\n") + "\n    },");

        // decoration
        const dec = [];
        if (o.rounding !== undefined) dec.push(`        rounding = ${luaNum(o.rounding, 8, 0)},`);
        if (o.inactive_opacity !== undefined) dec.push(`        inactive_opacity = ${luaNum(o.inactive_opacity, 1.0, 2)},`);
        const blur = [];
        if (o.blur_enabled !== undefined) blur.push(`            enabled = ${o.blur_enabled ? "true" : "false"},`);
        if (o.blur_size !== undefined) blur.push(`            size = ${luaNum(o.blur_size, 6, 0)},`);
        if (o.blur_passes !== undefined) blur.push(`            passes = ${luaNum(o.blur_passes, 3, 0)},`);
        if (blur.length > 0) dec.push("        blur = {\n" + blur.join("\n") + "\n        },");
        if (dec.length > 0) cfg.push("    decoration = {\n" + dec.join("\n") + "\n    },");

        // animations
        if (o.animations_enabled !== undefined) {
            cfg.push(`    animations = { enabled = ${o.animations_enabled ? "true" : "false"} },`);
        }

        // input
        const inp = [];
        if (o.kb_layout !== undefined) inp.push(`        kb_layout = ${luaStr(o.kb_layout)},`);
        if (o.kb_options !== undefined) inp.push(`        kb_options = ${luaStr(o.kb_options)},`);
        if (o.mouse_sensitivity !== undefined) inp.push(`        sensitivity = ${luaNum(o.mouse_sensitivity, 0.0, 2)},`);
        if (o.mouse_accel !== undefined) inp.push(`        accel_profile = ${luaStr(o.mouse_accel)},`);
        if (o.mouse_natural_scroll !== undefined) inp.push(`        natural_scroll = ${o.mouse_natural_scroll ? "true" : "false"},`);
        const tp = [];
        if (o.touchpad_natural_scroll !== undefined) tp.push(`            natural_scroll = ${o.touchpad_natural_scroll ? "true" : "false"},`);
        if (o.touchpad_tap_to_click !== undefined) tp.push(`            ["tap-to-click"] = ${o.touchpad_tap_to_click ? "true" : "false"},`);
        if (tp.length > 0) inp.push("        touchpad = {\n" + tp.join("\n") + "\n        },");
        if (inp.length > 0) cfg.push("    input = {\n" + inp.join("\n") + "\n    },");

        if (cfg.length > 0) {
            lines.push("hl.config({\n" + cfg.join("\n") + "\n})");
        }

        // touchpad device override
        if (root.touchpadName && (o.touchpad_sensitivity !== undefined || o.touchpad_natural_scroll !== undefined)) {
            const devLines = [`    name = ${luaStr(root.touchpadName)},`];
            if (o.touchpad_natural_scroll !== undefined)
                devLines.push(`    natural_scroll = ${o.touchpad_natural_scroll ? "true" : "false"},`);
            if (o.touchpad_sensitivity !== undefined)
                devLines.push(`    sensitivity = ${luaNum(o.touchpad_sensitivity, 0.03, 2)},`);
            lines.push("hl.device({\n" + devLines.join("\n") + "\n})");
        }

        // monitors
        if (Array.isArray(o.monitors) && o.monitors.length > 0) {
            for (const m of o.monitors) {
                lines.push(monitorSpecToLua(m));
            }
        }

        return lines.join("\n") + "\n";
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    function saveNow() {
        saveTimer.stop();
        jsonStore.setText(JSON.stringify({
            overrides: root.overrides,
            capsOsdEnabled: root.capsOsdEnabled
        }, null, 2));
        luaStore.setText(generateLuaOverrides());
    }

    // ---- Timers & Persistence ----

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: root.saveNow()
    }

    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.revertCountdown <= 1) {
                root.revertMonitors();
            } else {
                root.revertCountdown = root.revertCountdown - 1;
            }
        }
    }

    Timer {
        id: monRefreshDelay
        interval: 450
        onTriggered: root.refreshMonitors()
    }

    Timer {
        id: devRefreshDelay
        interval: 250
        onTriggered: root.refreshDevices()
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
    }

    FileView {
        id: jsonStore
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.overrides && typeof d.overrides === "object") root.overrides = d.overrides;
                    if (d.capsOsdEnabled !== undefined) root.capsOsdEnabled = Boolean(d.capsOsdEnabled);
                }
            } catch (e) {}
        }
    }

    FileView {
        id: luaStore
        path: root.luaOverrideFile
        atomicWrites: true
        printErrors: false
    }

    // ---- Hyprland Socket Events (layout switches, monitor hotplug) ----
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event.name;
            if (name === "activelayout") {
                const parts = String(event.data || "").split(",");
                const layout = parts.length >= 2 ? parts.slice(1).join(",").trim() : String(event.data || "").trim();
                if (layout && layout !== root.activeKeymap) {
                    root.activeKeymap = layout;
                    root.layoutSwitched(layout);
                }
            } else if (name === "monitoradded" || name === "monitorremoved" || name === "configreloaded") {
                monRefreshDelay.restart();
            }
        }
    }

    // ---- Monitor Query (`hyprctl monitors all -j`) ----
    Process {
        id: monProc
        command: ["timeout", "4", "hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monitorsLoading = false;
                try {
                    const list = JSON.parse(text.trim());
                    if (Array.isArray(list)) {
                        root.monitors = list.map(m => ({
                            id: m.id,
                            name: m.name || "",
                            description: m.description || "",
                            make: m.make || "",
                            model: m.model || "",
                            width: Number(m.width) || 1920,
                            height: Number(m.height) || 1080,
                            refreshRate: Number(m.refreshRate) || 60,
                            x: Number(m.x) || 0,
                            y: Number(m.y) || 0,
                            scale: Number(m.scale) || 1,
                            transform: Number(m.transform) || 0,
                            focused: Boolean(m.focused),
                            disabled: Boolean(m.disabled),
                            vrr: Boolean(m.vrr),
                            availableModes: Array.isArray(m.availableModes) ? m.availableModes : []
                        }));
                    }
                } catch (e) {}
            }
        }
        onExited: root.monitorsLoading = false
    }

    // ---- Input Devices Query (`hyprctl devices -j`) ----
    Process {
        id: devProc
        command: ["timeout", "4", "hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim());
                    if (d && Array.isArray(d.keyboards)) {
                        const mainKb = d.keyboards.find(k => k.main) || d.keyboards[0];
                        if (mainKb) {
                            root.activeKeyboardName = mainKb.name || "";
                            root.activeKeymap = mainKb.active_keymap || "";
                            if (mainKb.layout)
                                root.kbLayouts = String(mainKb.layout).split(",").map(s => s.trim()).filter(Boolean);
                            if (mainKb.options !== undefined)
                                root.kbOptions = String(mainKb.options || "");
                            const newCaps = Boolean(mainKb.capsLock);
                            const newNum = Boolean(mainKb.numLock);
                            if (root._devicesReady && newCaps !== root.capsLockOn) {
                                root.capsLockOn = newCaps;
                                root.lockKeyChanged("Caps Lock", newCaps);
                            } else {
                                root.capsLockOn = newCaps;
                            }
                            if (root._devicesReady && newNum !== root.numLockOn) {
                                root.numLockOn = newNum;
                                root.lockKeyChanged("Num Lock", newNum);
                            } else {
                                root.numLockOn = newNum;
                            }
                            root._devicesReady = true;
                        }
                    }
                    if (d && Array.isArray(d.mice)) {
                        const tp = d.mice.find(m => (m.name || "").toLowerCase().includes("touchpad"));
                        if (tp && tp.name) root.touchpadName = tp.name;
                    }
                } catch (e) {}
            }
        }
    }
    property bool _devicesReady: false

    // ---- Live Hyprland Options Query ----
    Process {
        id: optProc
        command: [
            "sh", "-c",
            "for k in general:gaps_in general:gaps_out general:border_size decoration:rounding decoration:inactive_opacity decoration:blur:enabled decoration:blur:size decoration:blur:passes animations:enabled input:sensitivity input:accel_profile input:natural_scroll input:touchpad:natural_scroll input:touchpad:tap-to-click input:kb_layout input:kb_options; do " +
            "  printf '%s=' \"$k\"; timeout 2 hyprctl getoption \"$k\" -j 2>/dev/null | tr '\\n' ' '; echo ''; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (const line of lines) {
                    const eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    const k = line.slice(0, eq).trim();
                    const raw = line.slice(eq + 1).trim();
                    if (!raw) continue;
                    try {
                        const o = JSON.parse(raw);
                        if (k === "general:gaps_in" && o.custom) root.gapsIn = parseInt(String(o.custom).split(" ")[0]) || 0;
                        else if (k === "general:gaps_out" && o.custom) root.gapsOut = parseInt(String(o.custom).split(" ")[0]) || 0;
                        else if (k === "general:border_size" && o.int !== undefined) root.borderSize = Number(o.int);
                        else if (k === "decoration:rounding" && o.int !== undefined) root.rounding = Number(o.int);
                        else if (k === "decoration:inactive_opacity" && o.float !== undefined) root.inactiveOpacity = Number(o.float);
                        else if (k === "decoration:blur:enabled" && o.int !== undefined) root.blurEnabled = Boolean(o.int);
                        else if (k === "decoration:blur:size" && o.int !== undefined) root.blurSize = Number(o.int);
                        else if (k === "decoration:blur:passes" && o.int !== undefined) root.blurPasses = Number(o.int);
                        else if (k === "animations:enabled" && o.int !== undefined) root.animationsEnabled = Boolean(o.int);
                        else if (k === "input:sensitivity" && o.float !== undefined) root.mouseSensitivity = Number(o.float);
                        else if (k === "input:accel_profile" && o.str !== undefined) root.mouseAccelProfile = o.str || "flat";
                        else if (k === "input:natural_scroll" && o.int !== undefined) root.mouseNaturalScroll = Boolean(o.int);
                        else if (k === "input:touchpad:natural_scroll" && o.int !== undefined) root.touchpadNaturalScroll = Boolean(o.int);
                        else if (k === "input:touchpad:tap-to-click" && o.int !== undefined) root.touchpadTapToClick = Boolean(o.int);
                        else if (k === "input:kb_layout" && o.str) root.kbLayouts = String(o.str).split(",").map(s => s.trim()).filter(Boolean);
                        else if (k === "input:kb_options" && o.str !== undefined) root.kbOptions = String(o.str);
                    } catch (e) {}
                }
            }
        }
    }

    // ---- Keybinds Query (`hyprctl binds -j`) ----
    function modmaskToString(mask: int): string {
        const mods = [];
        if (mask & 64) mods.push("SUPER");
        if (mask & 4)  mods.push("CTRL");
        if (mask & 8)  mods.push("ALT");
        if (mask & 1)  mods.push("SHIFT");
        return mods.join(" + ");
    }

    function categorizeBind(dispatcher: string, arg: string, key: string): var {
        const d = (dispatcher || "").toLowerCase();
        const a = (arg || "").toLowerCase();
        const k = (key || "").toLowerCase();
        if (a.includes("ipc call") || a.includes("lock-session") || a.includes("restart-shell"))
            return { cat: "Desktop Shell", desc: describeIpcBind(arg) };
        if (k.includes("print") || a.includes("capture"))
            return { cat: "Screenshots & Capture", desc: describeCaptureBind(arg) };
        if (k.startsWith("xf86") || a.includes("wpctl") || a.includes("playerctl") || a.includes("brightnessctl"))
            return { cat: "Media & Hardware", desc: describeMediaBind(arg, key) };
        if (d.includes("workspace") || a.includes("workspace"))
            return { cat: "Workspaces", desc: describeWsBind(dispatcher, arg) };
        if (d.includes("layoutmsg") || a.includes("col") || a.includes("movewindow") || a.includes("focus"))
            return { cat: "Windows & Layout", desc: describeWindowBind(dispatcher, arg) };
        if (d === "exec")
            return { cat: "Applications", desc: "Launch " + arg.split(" ")[0] };
        return { cat: "Windows & Layout", desc: (dispatcher + " " + arg).trim() };
    }

    function describeIpcBind(arg: string): string {
        if (arg.includes("launcher toggle")) return "Toggle App Launcher";
        if (arg.includes("launcher emoji")) return "Open Emoji Picker";
        if (arg.includes("overview")) return "Toggle Workspace Overview";
        if (arg.includes("quicksettings")) return "Toggle Quick Settings";
        if (arg.includes("clipboard")) return "Toggle Clipboard History";
        if (arg.includes("notifications")) return "Toggle Notification Center";
        if (arg.includes("power")) return "Open Power Menu";
        if (arg.includes("picker color")) return "Pick Pixel Color";
        if (arg.includes("capture toggle")) return "Open Capture Studio";
        if (arg.includes("capture snip")) return "Interactive Screen Capture (" + arg.split(" ").pop() + ")";
        if (arg.includes("settings")) return "Open HCS Settings";
        if (arg.includes("lock-session")) return "Lock Screen";
        if (arg.includes("restart-shell")) return "Restart Shell & Reload Hyprland";
        return arg;
    }

    function describeCaptureBind(arg: string): string {
        if (arg.includes("snip output")) return "Freeze & Capture Screen";
        if (arg.includes("snip window")) return "Freeze & Capture Window";
        if (arg.includes("snip region")) return "Freeze & Capture Region";
        if (arg.includes("shot output")) return "Quick Screenshot Output to Clipboard";
        if (arg.includes("shot region")) return "Quick Screenshot Region to Clipboard";
        return arg;
    }

    function describeMediaBind(arg: string, key: string): string {
        if (arg.includes("5%+")) return "Volume Up (+5%)";
        if (arg.includes("5%-")) return "Volume Down (-5%)";
        if (arg.includes("DEFAULT_AUDIO_SINK") && arg.includes("toggle")) return "Toggle Audio Mute";
        if (arg.includes("DEFAULT_AUDIO_SOURCE")) return "Toggle Microphone Mute";
        if (arg.includes("play-pause")) return "Play / Pause Media";
        if (arg.includes("next")) return "Next Track";
        if (arg.includes("previous")) return "Previous Track";
        if (arg.includes("10%-")) return "Screen Brightness Down";
        if (arg.includes("+10%")) return "Screen Brightness Up";
        return arg || key;
    }

    function describeWsBind(dispatcher: string, arg: string): string {
        if (dispatcher === "togglespecialworkspace") return "Toggle Scratchpad (" + arg + ")";
        if (dispatcher === "movetoworkspace") return "Move Window to Workspace " + arg;
        if (dispatcher === "workspace") return "Switch to Workspace " + arg;
        return (dispatcher + " " + arg).trim();
    }

    function describeWindowBind(dispatcher: string, arg: string): string {
        if (dispatcher === "killactive") return "Close Active Window";
        if (dispatcher === "togglefloating") return "Toggle Window Floating";
        if (dispatcher === "fullscreen") return arg === "1" ? "Toggle Maximize" : "Toggle Fullscreen";
        if (dispatcher === "pseudo") return "Toggle Pseudotile";
        if (dispatcher === "movefocus") return "Focus Direction (" + arg + ")";
        if (dispatcher === "movewindow") return "Move Window (" + arg + ")";
        return (dispatcher + " " + arg).trim();
    }

    Process {
        id: bindsProc
        command: ["timeout", "4", "hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.keybindsLoading = false;
                try {
                    const list = JSON.parse(text.trim());
                    if (!Array.isArray(list)) return;
                    const out = [];
                    const seen = {};
                    for (const b of list) {
                        if (!b.key || b.key.startsWith("switch:")) continue;
                        const modStr = root.modmaskToString(Number(b.modmask) || 0);
                        const combo = modStr ? (modStr + " + " + b.key) : b.key;
                        const dedupeKey = combo + "|" + (b.dispatcher || "") + "|" + (b.arg || "");
                        if (seen[dedupeKey]) continue;
                        seen[dedupeKey] = true;
                        const meta = root.categorizeBind(b.dispatcher || "", b.arg || "", b.key || "");
                        const desc = (b.description && String(b.description).trim() !== "") ? String(b.description).trim() : meta.desc;
                        out.push({
                            combo: combo,
                            key: b.key,
                            category: meta.cat,
                            description: desc,
                            dispatcher: b.dispatcher || "",
                            arg: b.arg || ""
                        });
                    }
                    root.keybinds = out;
                } catch (e) {}
            }
        }
        onExited: root.keybindsLoading = false
    }

    // Light polling for Caps/Num lock LED state via sysfs (in-process FileView, zero subprocesses)
    // and initial refresh on startup.
    Component.onCompleted: {
        refreshMonitors();
        refreshDevices();
        refreshLiveOptions();
    }
}
