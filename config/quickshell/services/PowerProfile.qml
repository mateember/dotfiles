pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Power profile / TLP mode (reads /sys/firmware/acpi/platform_profile in-process via FileView
// and switches via ~/dotfiles/scripts/tlpmodes.sh).
// Modes: "low-power" (Power Saver), "balanced" (Balanced), "performance" (Performance).
Singleton {
    id: root

    property string mode: "balanced"
    property bool manual: false
    property bool ready: false
    readonly property string script: (Quickshell.env("HOME") ?? "") + "/dotfiles/scripts/tlpmodes.sh"

    readonly property string label: {
        if (mode === "low-power") return "Power Saver";
        if (mode === "performance") return "Performance";
        return "Balanced";
    }

    readonly property string icon: {
        if (mode === "low-power") return "energy_savings_leaf";
        if (mode === "performance") return "bolt";
        return "speed";
    }

    function refresh() {
        prof.reload();
        manualFile.reload();
    }

    function _runScript(args) {
        const nextCmd = [root.script].concat(args);
        if (runProc.running) {
            runProc.pendingCmd = nextCmd;
            return;
        }
        runProc.cmd = nextCmd;
        runProc.running = true;
    }

    function setMode(m: string) {
        const arg = m === "low-power" ? "low" : m === "performance" ? "power" : "balanced";
        _runScript([arg]);
    }

    function setAuto() {
        _runScript(["auto"]);
    }

    function cycle() {
        _runScript([]);
    }

    FileView {
        id: prof
        path: "/sys/firmware/acpi/platform_profile"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
        onLoaded: {
            const v = text().trim();
            if (v) root.mode = v;
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }

    FileView {
        id: manualFile
        path: "/run/tlp/manual_mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.manual = text().trim().length > 0
        onLoadFailed: root.manual = false
    }

    // Re-check immediately (and after a short settle delay) when AC charger changes
    // since TLP applies platform_profile asynchronously via udev.
    Timer {
        id: acSettleTimer
        interval: 900
        property int remaining: 0
        repeat: true
        running: remaining > 0
        onTriggered: {
            root.refresh();
            remaining = Math.max(0, remaining - 1);
        }
    }

    Connections {
        target: Battery
        function onChargingChanged() {
            root.refresh();
            acSettleTimer.remaining = 3;
        }
        function onOnBatteryChanged() {
            root.refresh();
            acSettleTimer.remaining = 3;
        }
    }

    Process {
        id: runProc
        property var cmd: []
        property var pendingCmd: null
        command: cmd
        function drainPending() {
            if (running || pendingCmd === null) return;
            cmd = pendingCmd;
            pendingCmd = null;
            running = true;
        }
        onExited: {
            root.refresh();
            if (pendingCmd !== null) Qt.callLater(drainPending);
        }
    }

    // Low-frequency fallback reload (in-process FileView read, zero subprocesses)
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // qs ipc call powerprofile cycle | saver | balanced | performance | auto
    IpcHandler {
        target: "powerprofile"
        function cycle(): void { root.cycle(); }
        function saver(): void { root.setMode("low-power"); }
        function balanced(): void { root.setMode("balanced"); }
        function performance(): void { root.setMode("performance"); }
        function auto(): void { root.setAuto(); }
    }
}
