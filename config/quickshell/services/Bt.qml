pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ state via Quickshell.Bluetooth (no bluetoothctl).
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: (adapter?.devices.values ?? []).slice().sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string icon: !enabled ? "bluetooth_disabled"
                                 : connected.length > 0 ? "bluetooth_connected" : "bluetooth"

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
}
