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

    // ---- Extended Network Settings (saved Wi-Fi profiles, live IP/DNS/MAC details, hidden SSID) ----
    property var savedWifi: []       // [{ name, uuid, autoconnect, active }]
    property var activeDetails: ({}) // { device, ip4, ip6, gateway, dns, mac, speed }
    property string hiddenError: ""
    property bool hiddenBusy: false

    function refreshDetails() {
        if (!savedWifiProc.running) savedWifiProc.running = true;
        if (!detailsProc.running) detailsProc.running = true;
    }

    function forgetSavedConnection(uuid: string) {
        if (!uuid) return;
        Quickshell.execDetached(["nmcli", "connection", "delete", "uuid", uuid]);
        detailsRefreshTimer.restart();
    }

    function setConnectionAutoconnect(uuid: string, on: bool) {
        if (!uuid) return;
        Quickshell.execDetached(["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"]);
        detailsRefreshTimer.restart();
    }

    function connectHiddenWifi(ssid: string, password: string) {
        const s = (ssid || "").trim();
        if (!s || root.hiddenBusy) return;
        root.hiddenBusy = true;
        root.hiddenError = "";
        hiddenProc.command = [
            "python3", "-c",
            "import os, subprocess, sys, tempfile\n" +
            "ssid = sys.argv[1]\n" +
            "pw = sys.stdin.readline().rstrip('\\r\\n')\n" +
            "add_cmd = ['nmcli', '-g', 'UUID', 'connection', 'add', 'type', 'wifi', 'con-name', ssid, 'ssid', ssid, 'wifi.hidden', 'yes']\n" +
            "if pw:\n" +
            "    add_cmd += ['wifi-sec.key-mgmt', 'wpa-psk']\n" +
            "r_add = subprocess.run(add_cmd, text=True, capture_output=True)\n" +
            "if r_add.returncode != 0:\n" +
            "    sys.stderr.write(r_add.stderr or r_add.stdout)\n" +
            "    sys.exit(r_add.returncode)\n" +
            "uuid = r_add.stdout.strip().splitlines()[-1].strip()\n" +
            "path = None\n" +
            "try:\n" +
            "    up_cmd = ['nmcli', '--wait', '20', 'connection', 'up', 'uuid', uuid]\n" +
            "    if pw:\n" +
            "        rdir = os.environ.get('XDG_RUNTIME_DIR') or '/tmp'\n" +
            "        fd, path = tempfile.mkstemp(prefix='hcs-wifi-', dir=rdir)\n" +
            "        os.chmod(path, 0o600)\n" +
            "        with os.fdopen(fd, 'w') as f:\n" +
            "            f.write('802-11-wireless-security.psk:' + pw + '\\n')\n" +
            "        up_cmd += ['passwd-file', path]\n" +
            "    r_up = subprocess.run(up_cmd, text=True, capture_output=True)\n" +
            "    if r_up.returncode != 0:\n" +
            "        subprocess.run(['nmcli', 'connection', 'delete', 'uuid', uuid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
            "        sys.stderr.write(r_up.stderr or r_up.stdout)\n" +
            "        sys.exit(r_up.returncode)\n" +
            "finally:\n" +
            "    if path:\n" +
            "        try: os.unlink(path)\n" +
            "        except OSError: pass\n",
            s
        ];
        hiddenStdin.text = password || "";
        hiddenProc.stdinEnabled = true;
        hiddenProc.running = true;
    }

    Timer {
        id: detailsRefreshTimer
        interval: 450
        onTriggered: root.refreshDetails()
    }

    Process {
        id: savedWifiProc
        command: ["timeout", "4", "nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const cols = line.split(/(?<!\\):/).map(p => p.replace(/\\:/g, ":").replace(/\\\\/g, "\\"));
                    if (cols.length < 5) continue;
                    if (cols[2] !== "802-11-wireless") continue;
                    out.push({
                        name: cols[0],
                        uuid: cols[1],
                        autoconnect: cols[3] === "yes",
                        active: cols[4] === "yes"
                    });
                }
                out.sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name));
                root.savedWifi = out;
            }
        }
    }

    Process {
        id: detailsProc
        command: [
            "sh", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$3==\"connected\" && ($2==\"wifi\" || $2==\"ethernet\"){print $1; exit}'); " +
            "[ -z \"$dev\" ] && exit 0; " +
            "printf 'DEVICE=%s\\n' \"$dev\"; " +
            "nmcli -t -f GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,WIRED-PROPERTIES.SPEED dev show \"$dev\" 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = { device: "", ip4: "", ip6: "", gateway: "", dns: [], mac: "", speed: "" };
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    if (line.startsWith("DEVICE=")) { d.device = line.slice(7).trim(); continue; }
                    const idx = line.indexOf(":");
                    if (idx <= 0) continue;
                    const k = line.slice(0, idx).trim();
                    const v = line.slice(idx + 1).replace(/\\:/g, ":").trim();
                    if (!v) continue;
                    if (k === "GENERAL.HWADDR") d.mac = v;
                    else if (k.startsWith("IP4.ADDRESS") && !d.ip4) d.ip4 = v;
                    else if (k === "IP4.GATEWAY") d.gateway = v;
                    else if (k.startsWith("IP4.DNS")) d.dns.push(v);
                    else if (k.startsWith("IP6.ADDRESS") && !d.ip6 && !v.startsWith("fe80:")) d.ip6 = v;
                    else if (k === "WIRED-PROPERTIES.SPEED") d.speed = v;
                }
                d.dnsText = d.dns.join(", ");
                root.activeDetails = d;
            }
        }
    }

    QtObject {
        id: hiddenStdin
        property string text: ""
    }

    Process {
        id: hiddenProc
        property string errBuf: ""
        property bool procExited: false
        property bool errDone: false
        property int exitCode: 0
        function maybeFinish() {
            if (!procExited || !errDone) return;
            root.hiddenBusy = false;
            if (exitCode === 0) root.hiddenError = "";
            else root.hiddenError = (errBuf || "Could not connect to hidden network").replace(/^Error:\s*/i, "");
            hiddenStdin.text = "";
            command = [];
            root.refreshDetails();
        }
        onStarted: {
            errBuf = "";
            procExited = false;
            errDone = false;
            write(hiddenStdin.text + "\n");
            hiddenStdin.text = "";
        }
        stderr: StdioCollector {
            onStreamFinished: {
                hiddenProc.errBuf = text.trim();
                hiddenProc.errDone = true;
                hiddenProc.maybeFinish();
            }
        }
        onExited: code => {
            hiddenProc.exitCode = code;
            hiddenProc.procExited = true;
            hiddenStdin.text = "";
            hiddenProc.maybeFinish();
        }
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
