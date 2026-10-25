pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Minimon-style system monitor service:
// Reads CPU %, CPU package temperature, RAM/Swap, Network RX/TX, Disk R/W, and Intel Arc GPU usage
// from /proc and /sys, maintains 30-sample rolling histories for sparklines, and persists bar display settings.
Singleton {
    id: root

    // Current values
    property real cpu: 0              // 0..1
    property real tempC: 0            // °C
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real shmemGiB: 0
    property real netDownBps: 0       // bytes/s
    property real netUpBps: 0         // bytes/s
    property real diskReadBps: 0      // bytes/s
    property real diskWriteBps: 0     // bytes/s
    property real gpu: 0              // 0..1
    property int gpuFreqMHz: 0
    property int gpuMaxFreqMHz: 2200

    // Rolling histories (30 samples, 0..1)
    readonly property int historyLen: 30
    property var cpuHistory: []
    property var tempHistory: []
    property var memHistory: []
    property var netHistory: []
    property var diskHistory: []
    property var gpuHistory: []

    property string tempPath: ""
    property int sampleTick: 0

    // Persistent Minimon settings
    readonly property string stateFile: Quickshell.statePath("minimon-config.json")
    property int interval: 1500
    property bool netInBits: true
    property string monitorApp: "gnome-system-monitor"

    readonly property var defaultSensors: ({
        cpu:  { prefix: "none", text: true,  chart: "graph" },
        temp: { prefix: "none", text: true,  chart: "graph" },
        mem:  { prefix: "none", text: true,  chart: "graph" },
        net:  { prefix: "none", text: true,  chart: "graph" },
        disk: { prefix: "none", text: false, chart: "none"  },
        gpu:  { prefix: "none", text: true,  chart: "graph" }
    })
    property var sensors: JSON.parse(JSON.stringify(defaultSensors))

    function sensorPrefix(id: string): string {
        return (root.sensors[id] ?? root.defaultSensors[id])?.prefix ?? "none";
    }

    function sensorText(id: string): bool {
        return Boolean((root.sensors[id] ?? root.defaultSensors[id])?.text);
    }

    function sensorChart(id: string): string {
        return (root.sensors[id] ?? root.defaultSensors[id])?.chart ?? "none";
    }

    function setSensorPrefix(id: string, mode: string) {
        const next = JSON.parse(JSON.stringify(root.sensors));
        if (!next[id]) next[id] = { prefix: "none", text: true, chart: "none" };
        next[id].prefix = mode;
        root.sensors = next;
        root.saveConfig();
    }

    function setSensorText(id: string, on: bool) {
        const next = JSON.parse(JSON.stringify(root.sensors));
        if (!next[id]) next[id] = { prefix: "none", text: true, chart: "none" };
        next[id].text = on;
        root.sensors = next;
        root.saveConfig();
    }

    function setSensorChart(id: string, mode: string) {
        const next = JSON.parse(JSON.stringify(root.sensors));
        if (!next[id]) next[id] = { prefix: "none", text: true, chart: "none" };
        next[id].chart = mode;
        root.sensors = next;
        root.saveConfig();
    }

    function applyPreset(preset: string) {
        const next = JSON.parse(JSON.stringify(root.sensors));
        for (const k of Object.keys(next)) {
            if (preset === "icons") {
                next[k].prefix = "icon";
                next[k].chart = "none";
            } else if (preset === "labels") {
                next[k].prefix = "label";
                next[k].chart = "none";
            } else if (preset === "graphs") {
                next[k].prefix = "none";
                if (next[k].text) next[k].chart = "graph";
            }
        }
        root.sensors = next;
        root.saveConfig();
    }

    function resetConfig() {
        root.interval = 1500;
        root.netInBits = true;
        root.monitorApp = "gnome-system-monitor";
        root.sensors = JSON.parse(JSON.stringify(root.defaultSensors));
        root.saveConfig();
    }

    function saveConfig() {
        const data = JSON.stringify({
            interval: root.interval,
            netInBits: root.netInBits,
            monitorApp: root.monitorApp,
            sensors: root.sensors
        }, null, 2);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "sh", root.stateFile, data]);
    }

    function openSystemMonitor() {
        if (root.monitorApp === "btop")
            Quickshell.execDetached(["kitty", "-e", "btop"]);
        else
            Quickshell.execDetached(["sh", "-c", "command -v cosmic-observatory >/dev/null 2>&1 && exec cosmic-observatory || command -v gnome-system-monitor >/dev/null 2>&1 && exec gnome-system-monitor || exec kitty -e btop"]);
    }

    function formatNetRate(bytesPerSec: real): string {
        if (root.netInBits) {
            const bps = Math.max(0, bytesPerSec * 8);
            if (bps >= 1e9) return (bps / 1e9).toFixed(2) + " Gbps";
            if (bps >= 1e6) return (bps / 1e6).toFixed(1) + " Mbps";
            return Math.round(bps / 1e3) + " Kbps";
        } else {
            const b = Math.max(0, bytesPerSec);
            if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB/s";
            if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
            return Math.round(b / 1024) + " KB/s";
        }
    }

    function formatDiskRate(bytesPerSec: real): string {
        const b = Math.max(0, bytesPerSec);
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB/s";
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return "0 KB/s";
    }

    function pushSample(arr: var, v: real): var {
        const clamped = Math.max(0, Math.min(1, isNaN(v) ? 0 : v));
        const next = arr.slice(Math.max(0, arr.length - (root.historyLen - 1)));
        next.push(clamped);
        while (next.length < root.historyLen) next.unshift(0);
        return next;
    }

    property var _prevCpu: null
    property var _prevNet: null
    property var _prevDisk: null
    property var _prevGpu: null

    function parseStat(text: string) {
        const f = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (root._prevCpu) {
            const dt = total - root._prevCpu.total;
            if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prevCpu.idle) / dt));
        }
        root._prevCpu = { idle, total };
        root.cpuHistory = pushSample(root.cpuHistory, root.cpu);
    }

    function parseMem(text: string) {
        const get = k => Number((text.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) || [0, 0])[1]);
        const total = get("MemTotal"), avail = get("MemAvailable");
        const swapTot = get("SwapTotal"), swapFree = get("SwapFree");
        const shmem = get("Shmem");
        root.memTotalGiB = total / 1048576;
        root.memUsedGiB = (total - avail) / 1048576;
        root.swapTotalGiB = swapTot / 1048576;
        root.swapUsedGiB = (swapTot - swapFree) / 1048576;
        root.shmemGiB = shmem / 1048576;
        const frac = root.memTotalGiB > 0 ? root.memUsedGiB / root.memTotalGiB : 0;
        root.memHistory = pushSample(root.memHistory, frac);
    }

    function parseNet(text: string) {
        const now = Date.now();
        let rx = 0, tx = 0;
        const lines = text.split("\n").slice(2);
        for (const line of lines) {
            const m = line.trim().match(/^([^:]+):\s*(.+)$/);
            if (!m) continue;
            const iface = m[1].trim();
            if (iface === "lo") continue;
            const cols = m[2].trim().split(/\s+/).map(Number);
            if (cols.length >= 9) {
                rx += cols[0] || 0;
                tx += cols[8] || 0;
            }
        }
        if (root._prevNet) {
            const dt = (now - root._prevNet.time) / 1000;
            if (dt > 0) {
                root.netDownBps = Math.max(0, (rx - root._prevNet.rx) / dt);
                root.netUpBps = Math.max(0, (tx - root._prevNet.tx) / dt);
            }
        }
        root._prevNet = { rx, tx, time: now };
        // Normalize network graph against 10 MB/s (or peak in window)
        const combined = root.netDownBps + root.netUpBps;
        const norm = Math.min(1, Math.log10(1 + combined / 1024) / 5);
        root.netHistory = pushSample(root.netHistory, norm);
    }

    function parseDisk(text: string) {
        const now = Date.now();
        let rSectors = 0, wSectors = 0;
        for (const line of text.split("\n")) {
            const cols = line.trim().split(/\s+/);
            if (cols.length < 10) continue;
            const dev = cols[2];
            if (/^(nvme\d+n\d+|sd[a-z]|vd[a-z]|mmcblk\d+)$/.test(dev)) {
                rSectors += Number(cols[5]) || 0;
                wSectors += Number(cols[9]) || 0;
            }
        }
        if (root._prevDisk) {
            const dt = (now - root._prevDisk.time) / 1000;
            if (dt > 0) {
                root.diskReadBps = Math.max(0, (rSectors - root._prevDisk.r) * 512 / dt);
                root.diskWriteBps = Math.max(0, (wSectors - root._prevDisk.w) * 512 / dt);
            }
        }
        root._prevDisk = { r: rSectors, w: wSectors, time: now };
        const combined = root.diskReadBps + root.diskWriteBps;
        const norm = Math.min(1, Math.log10(1 + combined / 1024) / 5.5);
        root.diskHistory = pushSample(root.diskHistory, norm);
    }

    function parseGpuIdle(text: string) {
        const now = Date.now();
        const idleMs = Number(text.trim());
        if (!isNaN(idleMs) && root._prevGpu) {
            const dt = now - root._prevGpu.time;
            const dIdle = idleMs - root._prevGpu.idleMs;
            if (dt > 0 && dIdle >= 0) {
                root.gpu = Math.max(0, Math.min(1, 1 - dIdle / dt));
            }
        }
        if (!isNaN(idleMs))
            root._prevGpu = { idleMs, time: now };
        root.gpuHistory = pushSample(root.gpuHistory, root.gpu);
    }

    FileView {
        id: configStore
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (typeof d.interval === "number" && d.interval >= 500) root.interval = d.interval;
                if (typeof d.netInBits === "boolean") root.netInBits = d.netInBits;
                if (typeof d.monitorApp === "string") root.monitorApp = d.monitorApp;
                if (d.sensors && typeof d.sensors === "object") {
                    const merged = JSON.parse(JSON.stringify(root.defaultSensors));
                    for (const k of Object.keys(merged)) {
                        if (d.sensors[k]) {
                            merged[k].prefix = String(d.sensors[k].prefix || "none");
                            merged[k].text = Boolean(d.sensors[k].text);
                            merged[k].chart = String(d.sensors[k].chart || "none");
                        }
                    }
                    root.sensors = merged;
                }
            } catch (e) {}
        }
    }

    FileView { id: stat; path: "/proc/stat"; onLoaded: root.parseStat(text()) }
    FileView { id: mem; path: "/proc/meminfo"; onLoaded: root.parseMem(text()) }
    FileView { id: net; path: "/proc/net/dev"; onLoaded: root.parseNet(text()) }
    FileView { id: disk; path: "/proc/diskstats"; onLoaded: root.parseDisk(text()) }
    FileView {
        id: temp
        path: root.tempPath
        printErrors: false
        onLoaded: {
            root.tempC = Number(text()) / 1000;
            const norm = Math.max(0, Math.min(1, (root.tempC - 25) / 75));
            root.tempHistory = pushSample(root.tempHistory, norm);
        }
    }
    FileView {
        id: gpuIdle
        path: "/sys/class/drm/card0/device/tile0/gt0/gtidle/idle_residency_ms"
        printErrors: false
        onLoaded: root.parseGpuIdle(text())
    }
    FileView {
        id: gpuFreq
        path: "/sys/class/drm/card0/device/tile0/gt0/freq0/act_freq"
        printErrors: false
        onLoaded: root.gpuFreqMHz = Number(text().trim()) || 0
    }
    FileView {
        id: gpuMaxFreq
        path: "/sys/class/drm/card0/device/tile0/gt0/freq0/max_freq"
        printErrors: false
        onLoaded: root.gpuMaxFreqMHz = Number(text().trim()) || 2200
    }

    // CPU package sensor, looked up by driver name because hwmon numbers change between boots.
    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
              case "$(cat "$h/name")" in coretemp|k10temp|zenpower)
                for l in "$h"/temp*_label; do
                  case "$(cat "$l")" in "Package id 0"|Tctl|Tdie) echo "\${l%_label}_input"; exit;; esac
                done
                echo "$h/temp1_input"; exit;;
              esac
            done
            for z in /sys/class/thermal/thermal_zone*; do
              [ "$(cat "$z/type")" = x86_pkg_temp ] && { echo "$z/temp"; exit; }
            done
            echo /sys/class/thermal/thermal_zone0/temp`]
        stdout: StdioCollector { onStreamFinished: root.tempPath = text.trim() }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            mem.reload();
            net.reload();
            disk.reload();
            gpuIdle.reload();
            gpuFreq.reload();
            if (root.tempPath !== "") temp.reload();
            root.sampleTick = (root.sampleTick + 1) % 1000000;
        }
    }
}
