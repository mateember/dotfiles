pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Native KDE Connect continuity bridge via `kdeconnect-cli` and `busctl` (zero external scripts).
Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property var devices: []       // [{ id, name, reachable, paired, battery, charging }]
    property string lastMessage: ""

    readonly property var reachableDevices: devices.filter(d => d.reachable && d.paired)
    readonly property var pairedDevices: devices.filter(d => d.paired)

    function refresh() {
        if (listProc.running) return;
        root.loading = true;
        listProc.running = true;
    }

    function ring(deviceId: string) {
        if (!deviceId) return;
        root.lastMessage = "Ringing device…";
        Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--ring"]);
    }

    function ping(deviceId: string) {
        if (!deviceId) return;
        root.lastMessage = "Ping sent";
        Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--ping-msg", "Ping from HCS Desktop"]);
    }

    function sendClipboard(deviceId: string) {
        if (!deviceId) return;
        root.lastMessage = "Sent clipboard to phone";
        Quickshell.execDetached(["sh", "-c", "txt=$(wl-paste 2>/dev/null); [ -n \"$txt\" ] && kdeconnect-cli -d \"$1\" --share-text \"$txt\"", "sh", deviceId]);
    }

    function sendFile(deviceId: string) {
        if (!deviceId) return;
        Quickshell.execDetached(["sh", "-c",
            "f=$(zenity --file-selection --title='Send file to phone' 2>/dev/null); [ -n \"$f\" ] && kdeconnect-cli -d \"$1\" --share \"$f\"",
            "sh", deviceId]);
    }

    function pair(deviceId: string) {
        if (!deviceId) return;
        root.lastMessage = "Pairing requested — accept on your phone";
        Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--pair"]);
        refreshLater.restart();
    }

    function unpair(deviceId: string) {
        if (!deviceId) return;
        root.lastMessage = "Device unpaired";
        Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--unpair"]);
        refreshLater.restart();
    }

    function openSettings() {
        Quickshell.execDetached(["kdeconnect-settings"]);
    }

    Timer {
        id: refreshLater
        interval: 2000
        onTriggered: root.refresh()
    }

    // Enumerate devices directly over D-Bus (immune to untrusted LAN device name spoofing
    // and locale/flag parsing bugs in `kdeconnect-cli -l`).
    Process {
        id: listProc
        command: [
            "python3", "-c",
            `
import json, re, shutil, subprocess, sys

if not shutil.which("kdeconnect-cli") and not shutil.which("busctl"):
    sys.exit(127)

def busctl_json(args, timeout=2):
    r = subprocess.run(["busctl", "--user", "--json=short"] + args, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)

try:
    res = busctl_json(["call", "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices", "bb", "false", "false"], timeout=3)
except Exception:
    sys.exit(127 if not shutil.which("kdeconnect-cli") else 1)

if res is None:
    sys.exit(127 if not shutil.which("kdeconnect-cli") else 1)

raw_ids = (res.get("data") or [[]])[0]
if not isinstance(raw_ids, list):
    raw_ids = []

id_re = re.compile(r"^[A-Za-z0-9_.-]+$")
out = []
for dev_id in raw_ids:
    if not isinstance(dev_id, str) or not id_re.match(dev_id):
        continue
    base = f"/modules/kdeconnect/devices/{dev_id}"
    try:
        name_r = busctl_json(["get-property", "org.kde.kdeconnect", base, "org.kde.kdeconnect.device", "name"], timeout=1)
        paired_r = busctl_json(["get-property", "org.kde.kdeconnect", base, "org.kde.kdeconnect.device", "isPaired"], timeout=1)
        reach_r = busctl_json(["get-property", "org.kde.kdeconnect", base, "org.kde.kdeconnect.device", "isReachable"], timeout=1)
    except Exception:
        continue
    name = str((name_r or {}).get("data") or dev_id)
    paired = bool((paired_r or {}).get("data", False))
    reachable = bool((reach_r or {}).get("data", False))
    bat = -1
    chg = False
    if reachable:
        try:
            b_r = busctl_json(["get-property", "org.kde.kdeconnect", f"{base}/battery", "org.kde.kdeconnect.device.battery", "charge"], timeout=1)
            c_r = busctl_json(["get-property", "org.kde.kdeconnect", f"{base}/battery", "org.kde.kdeconnect.device.battery", "isCharging"], timeout=1)
            if b_r and isinstance(b_r.get("data"), (int, float)):
                bat = int(b_r["data"])
            if c_r:
                chg = bool(c_r.get("data", False))
        except Exception:
            pass
    out.append({"id": dev_id, "name": name, "paired": paired, "reachable": reachable, "battery": bat, "charging": chg})

out.sort(key=lambda d: (not d["reachable"], not d["paired"], d["name"].lower()))
print(json.dumps(out))
`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const parsed = JSON.parse(text.trim());
                    if (Array.isArray(parsed)) root.devices = parsed;
                } catch (e) {}
            }
        }
        onExited: code => {
            root.loading = false;
            root.available = (code !== 127);
        }
    }
}
