pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager state via Quickshell.Networking (Wi-Fi / Ethernet) + event-driven VPN manager.
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

    // Set while the Network popup is open to keep the Wi-Fi scan list fresh.
    property bool scanning: false

    // ---- VPN state (NetworkManager vpn & wireguard profiles) ----
    readonly property string scriptPath: Quickshell.shellPath("scripts/hardware-status.py")
    property var vpns: []
    readonly property var activeVpn: vpns.find(v => v.connected) ?? null
    readonly property bool vpnConnected: activeVpn !== null
    readonly property bool vpnConnecting: vpns.some(v => v.connecting)
    property string vpnBusyUuid: ""
    property string vpnSecretUuid: ""
    property string vpnError: ""
    property string _pendingActionUuid: ""

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

    function refreshVpns() {
        if (!vpnListProc.running) vpnListProc.running = true;
    }

    function toggleVpn(vpn) {
        if (!vpn || !vpn.uuid) return;
        if (vpn.connected || vpn.connecting) disconnectVpn(vpn.uuid);
        else connectVpn(vpn.uuid, "");
    }

    function connectVpn(uuid: string, password: string) {
        if (!uuid || vpnActionProc.running) return;
        root.vpnError = "";
        root.vpnSecretUuid = "";
        root.vpnBusyUuid = uuid;
        root._pendingActionUuid = uuid;
        if (password && password.length > 0) {
            vpnActionProc.command = [
                "python3", "-c",
                "import os, subprocess, sys, tempfile\n" +
                "uuid = sys.argv[1]\n" +
                "pw = sys.stdin.readline().rstrip('\\r\\n')\n" +
                "rdir = os.environ.get('XDG_RUNTIME_DIR') or '/tmp'\n" +
                "fd, path = tempfile.mkstemp(prefix='hcs-vpn-', dir=rdir)\n" +
                "try:\n" +
                "    os.chmod(path, 0o600)\n" +
                "    with os.fdopen(fd, 'w') as f:\n" +
                "        f.write('vpn.secrets.password:' + pw + '\\n')\n" +
                "    r = subprocess.run(['nmcli', '--wait', '25', 'connection', 'up', 'uuid', uuid, 'passwd-file', path], text=True, capture_output=True)\n" +
                "    if r.returncode != 0:\n" +
                "        sys.stderr.write(r.stderr or r.stdout)\n" +
                "        sys.exit(r.returncode)\n" +
                "finally:\n" +
                "    try: os.unlink(path)\n" +
                "    except OSError: pass\n",
                uuid
            ];
            vpnActionStdin.text = password;
            vpnActionProc.stdinEnabled = true;
        } else {
            vpnActionProc.stdinEnabled = false;
            vpnActionProc.command = ["nmcli", "--wait", "25", "connection", "up", "uuid", uuid];
        }
        vpnActionProc.running = true;
    }

    function disconnectVpn(uuid: string) {
        if (!uuid || vpnActionProc.running) return;
        root.vpnError = "";
        root.vpnSecretUuid = "";
        root.vpnBusyUuid = uuid;
        root._pendingActionUuid = uuid;
        vpnActionProc.stdinEnabled = false;
        vpnActionProc.command = ["nmcli", "--wait", "10", "connection", "down", "uuid", uuid];
        vpnActionProc.running = true;
    }

    function editVpn(uuid: string) {
        if (!uuid) return;
        Quickshell.execDetached(["nm-connection-editor", "-e", uuid]);
    }

    function createVpn() {
        Quickshell.execDetached(["nm-connection-editor", "-c", "-t", "vpn"]);
    }

    function openConnectionEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }

    QtObject {
        id: vpnActionStdin
        property string text: ""
    }

    Timer {
        id: vpnRefreshDebounce
        interval: 220
        onTriggered: root.refreshVpns()
    }

    // Event-driven NetworkManager listener (zero idle CPU wakeups).
    Process {
        id: nmMon
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: _ => vpnRefreshDebounce.restart()
        }
    }

    Process {
        id: vpnListProc
        command: ["python3", root.scriptPath, "vpns"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    if (Array.isArray(parsed)) root.vpns = parsed;
                } catch (e) {}
            }
        }
    }

    Process {
        id: vpnActionProc
        property string errBuf: ""
        onStarted: {
            errBuf = "";
            if (stdinEnabled && vpnActionStdin.text !== "") {
                write(vpnActionStdin.text + "\n");
                vpnActionStdin.text = "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: vpnActionProc.errBuf = text.trim()
        }
        onExited: (code, _status) => {
            const targetUuid = root._pendingActionUuid;
            root.vpnBusyUuid = "";
            root._pendingActionUuid = "";
            if (code !== 0) {
                const msg = vpnActionProc.errBuf || "VPN operation failed";
                const low = msg.toLowerCase();
                if (low.includes("no valid secrets") || low.includes("secrets were required") || low.includes("no secrets")) {
                    root.vpnSecretUuid = targetUuid;
                } else {
                    root.vpnError = msg.replace(/^Error:\s*/i, "");
                }
            }
            root.refreshVpns();
        }
    }

    Component.onCompleted: root.refreshVpns()

    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanning
    }
}
