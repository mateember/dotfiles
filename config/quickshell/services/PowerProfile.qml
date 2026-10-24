pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Power profile / TLP mode (reads /sys/firmware/acpi/platform_profile and switches via ~/dotfiles/scripts/tlpmodes.sh).
// Modes: "low-power" (Power Saver), "balanced" (Balanced), "performance" (Performance).
Singleton {
    id: root

    property string mode: "balanced"
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
    }

    function setMode(m: string) {
        if (runProc.running) return;
        const arg = m === "low-power" ? "low" : m === "performance" ? "power" : "balanced";
        runProc.cmd = [root.script, arg];
        runProc.running = true;
    }

    function cycle() {
        if (runProc.running) return;
        runProc.cmd = [root.script];
        runProc.running = true;
    }

    FileView {
        id: prof
        path: "/sys/firmware/acpi/platform_profile"
        printErrors: false
        onLoaded: {
            const v = text().trim();
            if (v) root.mode = v;
        }
    }

    Process {
        id: runProc
        property var cmd: []
        command: cmd
        onExited: prof.reload()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: prof.reload()
    }

    // qs ipc call powerprofile cycle | saver | balanced | performance
    IpcHandler {
        target: "powerprofile"
        function cycle(): void { root.cycle(); }
        function saver(): void { root.setMode("low-power"); }
        function balanced(): void { root.setMode("balanced"); }
        function performance(): void { root.setMode("performance"); }
    }
}
