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

    // Enumerate devices via kdeconnect-cli + fetch battery via busctl for reachable ones
    Process {
        id: listProc
        command: [
            "sh", "-c",
            "command -v kdeconnect-cli >/dev/null 2>&1 || exit 127; " +
            "timeout 4 kdeconnect-cli -l 2>/dev/null | while IFS= read -r line; do " +
            "  case \"$line\" in '- '*) " +
            "    rest=${line#- }; " +
            "    name=${rest%%: *}; " +
            "    after=${rest#*: }; " +
            "    id=${after%% *}; " +
            "    flags=${after#* }; " +
            "    bat=-1; chg=0; " +
            "    if echo \"$flags\" | grep -q 'reachable'; then " +
            "      b=$(timeout 1 busctl --user get-property org.kde.kdeconnect \"/modules/kdeconnect/devices/$id/battery\" org.kde.kdeconnect.device.battery charge 2>/dev/null | awk '{print $2}'); " +
            "      c=$(timeout 1 busctl --user get-property org.kde.kdeconnect \"/modules/kdeconnect/devices/$id/battery\" org.kde.kdeconnect.device.battery isCharging 2>/dev/null | awk '{print $2}'); " +
            "      [ -n \"$b\" ] && bat=$b; [ \"$c\" = \"true\" ] && chg=1; " +
            "    fi; " +
            "    printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$flags\" \"$bat\" \"$chg\"; " +
            "  ;; esac; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                const lines = text.trim().split("\n").filter(Boolean);
                const out = [];
                for (const line of lines) {
                    const cols = line.split("\t");
                    if (cols.length < 3) continue;
                    const id = cols[0].trim();
                    const name = cols[1].trim();
                    const flags = cols[2].toLowerCase();
                    const bat = parseInt(cols[3] ?? "-1");
                    const chg = (cols[4] ?? "0").trim() === "1";
                    out.push({
                        id: id,
                        name: name,
                        paired: flags.includes("paired"),
                        reachable: flags.includes("reachable"),
                        battery: isNaN(bat) ? -1 : bat,
                        charging: chg
                    });
                }
                out.sort((a, b) => (b.reachable - a.reachable) || (b.paired - a.paired) || a.name.localeCompare(b.name));
                root.devices = out;
            }
        }
        onExited: code => {
            root.loading = false;
            root.available = (code !== 127);
        }
    }
}
