pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// BlueZ state via Quickshell.Bluetooth + UPower battery fallback.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: (adapter?.devices.values ?? []).slice().sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    readonly property var connected: devices.filter(d => d.connected)

    // UPower fallback battery percentages keyed by uppercase MAC ("AA:BB:CC:DD:EE:FF": 85)
    property var upowerBatteries: ({})

    readonly property string icon: !enabled ? "bluetooth_disabled"
                                 : connected.length > 0 ? "bluetooth_connected" : "bluetooth"

    // Primary connected device battery (0..100 or -1 if none)
    readonly property int primaryBattery: {
        for (const d of root.connected) {
            const b = root.deviceBattery(d);
            if (b >= 0) return b;
        }
        return -1;
    }

    function toggle() { if (root.adapter) root.adapter.enabled = !root.adapter.enabled; }
    function setDiscovering(on: bool) {
        if (root.adapter && root.adapter.enabled && root.adapter.discovering !== on)
            root.adapter.discovering = on;
    }

    // Connected → disconnect. Paired → connect. New → trust + pair (click again to connect).
    function activate(device) {
        if (device.connected) device.disconnect();
        else if (device.paired || device.bonded) device.connect();
        else { device.trusted = true; device.pair(); }
    }

    function deviceBattery(device): int {
        if (!device) return -1;
        if (device.batteryAvailable && device.battery >= 0)
            return Math.round(device.battery * 100);
        const addr = (device.address || "").toUpperCase();
        if (addr && root.upowerBatteries[addr] !== undefined)
            return root.upowerBatteries[addr];
        return -1;
    }

    function batteryIcon(pct: int): string {
        if (pct < 0) return "";
        if (pct <= 15) return "battery_1_bar";
        if (pct <= 35) return "battery_2_bar";
        if (pct <= 55) return "battery_3_bar";
        if (pct <= 75) return "battery_4_bar";
        if (pct <= 90) return "battery_5_bar";
        return "battery_full";
    }

    function deviceIcon(device): string {
        const i = device.icon || "";
        if (i.includes("headset") || i.includes("headphone")) return "headphones";
        if (i.includes("audio") || i.includes("speaker")) return "speaker";
        if (i.includes("keyboard")) return "keyboard";
        if (i.includes("mouse")) return "mouse";
        if (i.includes("phone")) return "smartphone";
        if (i.includes("gaming") || i.includes("joystick")) return "sports_esports";
        return "bluetooth";
    }

    onConnectedChanged: {
        if (root.connected.length > 0 && !batProc.running) batProc.running = true;
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.connected.length > 0
        triggeredOnStart: true
        onTriggered: if (!batProc.running) batProc.running = true
    }

    Process {
        id: batProc
        command: ["python3", Quickshell.shellPath("scripts/hardware-status.py"), "bt-battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text.trim());
                    if (m && typeof m === "object") root.upowerBatteries = m;
                } catch (e) {}
            }
        }
    }
}
