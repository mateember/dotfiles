pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// NetworkManager state via Quickshell.Networking (no nmcli).
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wiredConnected: wiredDevice?.connected ?? false
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null
    readonly property real strength: activeWifi?.signalStrength ?? 0   // 0..1

    // Set while the Wi-Fi popup is open to keep the network list fresh.
    property bool scanning: false

    readonly property string icon: {
        if (wiredConnected) return "lan";
        if (!wifiEnabled) return "wifi_off";
        if (!activeWifi) return "signal_wifi_0_bar";
        return strengthIcon(strength);
    }

    function strengthIcon(s: real): string {
        if (s > 0.75) return "signal_wifi_4_bar";
        if (s > 0.5) return "network_wifi_3_bar";
        if (s > 0.25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    function isSecure(network): bool {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
    }

    function setWifiEnabled(on: bool) { Networking.wifiEnabled = on; }

    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanning
    }
}
