pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// System management backend for HCS Settings (pure QML + direct native CLI/FileView,
// zero external scripts):
// - About / hardware / NixOS summary
// - Lenovo IdeaPad Battery Conservation Mode
// - Tailscale status & exit-node switcher
// - Default applications (`xdg-mime`)
// - XDG Autostart entries
// - User systemd services (`systemctl --user`)
// - Date/time & timezone (`timedatectl`)
Singleton {
    id: root

    // ---- About & Hardware ----
    property string osName: "NixOS"
    property string nixosGeneration: ""
    property string kernel: ""
    property string hostname: ""
    property string cpuModel: ""
    property string gpuModel: ""
    property string ramTotal: ""
    property string diskUsage: ""
    property string hyprlandVersion: ""
    property string quickshellVersion: ""
    property string uptimeText: ""

    // ---- IdeaPad Battery Conservation Mode ----
    readonly property string conservationPath: "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"
    property bool conservationAvailable: false
    property bool conservationEnabled: false
    property bool conservationBusy: false
    property string conservationError: ""

    // ---- Tailscale ----
    property bool tailscaleAvailable: false
    property bool tailscaleRunning: false
    property string tailscaleSelfName: ""
    property string tailscaleSelfIp: ""
    property string tailscaleActiveExitId: ""
    property string tailscaleActiveExitName: ""
    property var tailscaleExitNodes: []   // [{ id, name, dnsName, online, active }]
    property bool tailscaleBusy: false
    property string tailscaleError: ""

    // ---- Date & Time ----
    property string timezone: ""
    property bool ntpEnabled: true
    property bool ntpSynced: true
    property string clockFormat: persistClock.format
    property bool clockUse24h: persistClock.use24h
    property bool clockShowSeconds: persistClock.showSeconds
    property bool clockShowDate: persistClock.showDate

    // ---- Default Apps ----
    readonly property var defaultRoles: [
        { id: "browser",  label: "Web Browser",   icon: "public",          mime: "x-scheme-handler/https", extraMimes: ["x-scheme-handler/http", "text/html"] },
        { id: "files",    label: "File Manager",  icon: "folder",          mime: "inode/directory",        extraMimes: [] },
        { id: "editor",   label: "Text Editor",   icon: "edit_note",       mime: "text/plain",             extraMimes: [] },
        { id: "image",    label: "Image Viewer",  icon: "image",           mime: "image/png",              extraMimes: ["image/jpeg", "image/webp"] },
        { id: "video",    label: "Video Player",  icon: "movie",           mime: "video/mp4",              extraMimes: ["video/x-matroska", "video/webm"] },
        { id: "audio",    label: "Audio Player",  icon: "music_note",      mime: "audio/mpeg",             extraMimes: ["audio/flac", "audio/ogg"] },
        { id: "pdf",      label: "PDF Viewer",    icon: "picture_as_pdf",  mime: "application/pdf",        extraMimes: [] }
    ]
    property var defaultAppMap: ({})     // roleId -> desktopFile (e.g. "brave-browser.desktop")

    // ---- Autostart Entries ----
    property var autostartApps: []       // [{ file, name, exec, enabled, system, path }]
    property bool autostartLoading: false

    // ---- User Systemd Services ----
    property var userServices: []        // [{ unit, load, active, sub, description }]
    property bool servicesLoading: false
    property string serviceJournalUnit: ""
    property string serviceJournalText: ""

    // ---- Clock Format Persistence ----
    function rebuildClockFormat() {
        const timePart = root.clockUse24h
            ? (root.clockShowSeconds ? "HH:mm:ss" : "HH:mm")
            : (root.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP");
        persistClock.format = root.clockShowDate ? ("ddd, MMM d, " + timePart) : timePart;
        clockStore.setText(JSON.stringify({
            use24h: persistClock.use24h,
            showSeconds: persistClock.showSeconds,
            showDate: persistClock.showDate,
            format: persistClock.format
        }));
    }

    function setClockUse24h(v: bool) { persistClock.use24h = v; rebuildClockFormat(); }
    function setClockShowSeconds(v: bool) { persistClock.showSeconds = v; rebuildClockFormat(); }
    function setClockShowDate(v: bool) { persistClock.showDate = v; rebuildClockFormat(); }

    QtObject {
        id: persistClock
        property bool use24h: true
        property bool showSeconds: false
        property bool showDate: true
        property string format: "ddd, MMM d, HH:mm"
    }

    FileView {
        id: clockStore
        path: Quickshell.statePath("clock-config.json")
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.use24h !== undefined) persistClock.use24h = Boolean(d.use24h);
                    if (d.showSeconds !== undefined) persistClock.showSeconds = Boolean(d.showSeconds);
                    if (d.showDate !== undefined) persistClock.showDate = Boolean(d.showDate);
                    if (d.format) persistClock.format = String(d.format);
                }
            } catch (e) {}
        }
    }

    // ---- IdeaPad Conservation Mode ----
    FileView {
        id: conservationFile
        path: root.conservationPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.conservationAvailable = true;
            root.conservationEnabled = text().trim() === "1";
        }
        onLoadFailed: root.conservationAvailable = false
    }

    function refreshConservation() {
        conservationFile.reload();
    }

    function setConservationMode(on: bool) {
        if (!root.conservationAvailable || root.conservationBusy) return;
        root.conservationBusy = true;
        root.conservationError = "";
        const val = on ? "1" : "0";
        conservationProc.command = [
            "sh", "-c",
            `printf '%s\\n' '${val}' | sudo -n tee '${root.conservationPath}' >/dev/null 2>&1 || printf '%s\\n' '${val}' | pkexec tee '${root.conservationPath}' >/dev/null`
        ];
        conservationProc.running = true;
    }

    Process {
        id: conservationProc
        stderr: StdioCollector {
            onStreamFinished: {
                const e = text.trim();
                if (e) root.conservationError = e;
            }
        }
        onExited: code => {
            root.conservationBusy = false;
            if (code === 0) root.conservationError = "";
            conservationFile.reload();
        }
    }

    // ---- Tailscale ----
    function refreshTailscale() {
        if (!tsStatusProc.running) tsStatusProc.running = true;
    }

    function setTailscaleExitNode(nodeNameOrEmpty: string) {
        if (root.tailscaleBusy) return;
        root.tailscaleBusy = true;
        root.tailscaleError = "";
        const target = String(nodeNameOrEmpty || "");
        tsSetProc.command = [
            "sh", "-c",
            "tailscale set --exit-node=\"$1\" 2>/dev/null || sudo -n tailscale set --exit-node=\"$1\" 2>/dev/null || pkexec tailscale set --exit-node=\"$1\"",
            "sh", target
        ];
        tsSetProc.running = true;
    }

    Process {
        id: tsStatusProc
        command: ["timeout", "4", "tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim());
                    root.tailscaleAvailable = true;
                    root.tailscaleRunning = (d.BackendState === "Running");
                    const self = d.Self || {};
                    root.tailscaleSelfName = self.HostName || "";
                    root.tailscaleSelfIp = (Array.isArray(self.TailscaleIPs) && self.TailscaleIPs.length > 0) ? self.TailscaleIPs[0] : "";

                    const nodes = [];
                    let activeId = "";
                    let activeName = "";
                    const peers = d.Peer || {};
                    for (const k in peers) {
                        const p = peers[k];
                        if (!p) continue;
                        if (p.ExitNodeOption || p.ExitNode) {
                            const name = p.HostName || (p.DNSName || "").split(".")[0] || k;
                            const isAct = Boolean(p.ExitNode);
                            if (isAct) { activeId = p.ID || k; activeName = name; }
                            nodes.push({
                                id: p.ID || k,
                                name: name,
                                dnsName: (p.DNSName || "").replace(/\.$/, ""),
                                ip: (Array.isArray(p.TailscaleIPs) && p.TailscaleIPs.length > 0) ? p.TailscaleIPs[0] : "",
                                online: Boolean(p.Online),
                                active: isAct
                            });
                        }
                    }
                    nodes.sort((a, b) => (b.active - a.active) || (b.online - a.online) || a.name.localeCompare(b.name));
                    root.tailscaleExitNodes = nodes;
                    root.tailscaleActiveExitId = activeId;
                    root.tailscaleActiveExitName = activeName;
                } catch (e) {}
            }
        }
        onExited: code => {
            if (code === 127) root.tailscaleAvailable = false;
        }
    }

    Process {
        id: tsSetProc
        stderr: StdioCollector {
            onStreamFinished: {
                const e = text.trim();
                if (e) root.tailscaleError = e;
            }
        }
        onExited: code => {
            root.tailscaleBusy = false;
            if (code === 0) root.tailscaleError = "";
            refreshTailscale();
        }
    }

    // ---- Date & Time (`timedatectl show`) ----
    function refreshTimeInfo() {
        if (!timeProc.running) timeProc.running = true;
    }

    Process {
        id: timeProc
        command: ["timeout", "3", "timedatectl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    const k = line.slice(0, eq).trim();
                    const v = line.slice(eq + 1).trim();
                    if (k === "Timezone") root.timezone = v;
                    else if (k === "NTP") root.ntpEnabled = (v === "yes");
                    else if (k === "NTPSynchronized") root.ntpSynced = (v === "yes");
                }
            }
        }
    }

    // ---- Default Apps (`xdg-mime`) ----
    function refreshDefaultApps() {
        if (!mimeQueryProc.running) mimeQueryProc.running = true;
    }

    function setDefaultApp(roleId: string, desktopId: string) {
        const role = defaultRoles.find(r => r.id === roleId);
        if (!role || !desktopId) return;
        const desktopFile = desktopId.endsWith(".desktop") ? desktopId : (desktopId + ".desktop");
        const mimes = [role.mime].concat(role.extraMimes || []);
        const next = Object.assign({}, root.defaultAppMap);
        next[roleId] = desktopFile;
        root.defaultAppMap = next;
        Quickshell.execDetached(["xdg-mime", "default", desktopFile].concat(mimes));
    }

    Process {
        id: mimeQueryProc
        command: [
            "sh", "-c",
            "for pair in 'browser:x-scheme-handler/https' 'files:inode/directory' 'editor:text/plain' 'image:image/png' 'video:video/mp4' 'audio:audio/mpeg' 'pdf:application/pdf'; do " +
            "  id=${pair%%:*}; m=${pair#*:}; " +
            "  printf '%s=%s\\n' \"$id\" \"$(xdg-mime query default \"$m\" 2>/dev/null)\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    map[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
                }
                root.defaultAppMap = map;
            }
        }
    }

    // ---- XDG Autostart Entries ----
    function refreshAutostart() {
        if (autostartProc.running) return;
        root.autostartLoading = true;
        autostartProc.running = true;
    }

    function setAutostartEnabled(fileName: string, appName: string, execCmd: string, enabled: bool) {
        if (!fileName) return;
        const dir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/autostart";
        const target = dir + "/" + fileName;
        const hiddenVal = enabled ? "false" : "true";
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$1\"; " +
            "if [ -f \"$2\" ]; then " +
            "  if grep -q '^Hidden=' \"$2\"; then sed -i \"s/^Hidden=.*/Hidden=$3/\" \"$2\"; else printf '\\nHidden=%s\\n' \"$3\" >> \"$2\"; fi; " +
            "else " +
            "  printf '[Desktop Entry]\\nType=Application\\nName=%s\\nExec=%s\\nHidden=%s\\n' \"$4\" \"$5\" \"$3\" > \"$2\"; " +
            "fi",
            "sh", dir, target, hiddenVal, appName || fileName, execCmd || "true"
        ]);
        autostartRefreshLater.restart();
    }

    Timer {
        id: autostartRefreshLater
        interval: 300
        onTriggered: root.refreshAutostart()
    }

    Process {
        id: autostartProc
        command: [
            "sh", "-c",
            "user_dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/autostart\"; " +
            "for dir in \"$user_dir\" /etc/xdg/autostart; do " +
            "  [ -d \"$dir\" ] || continue; " +
            "  for f in \"$dir\"/*.desktop; do " +
            "    [ -f \"$f\" ] || continue; " +
            "    bn=$(basename \"$f\"); " +
            "    name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "    exe=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
            "    hid=$(grep -m1 '^Hidden=' \"$f\" | cut -d= -f2- | tr '[:upper:]' '[:lower:]'); " +
            "    sys=1; [ \"$dir\" = \"$user_dir\" ] && sys=0; " +
            "    printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$bn\" \"${name:-$bn}\" \"$exe\" \"${hid:-false}\" \"$sys\"; " +
            "  done; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.autostartLoading = false;
                const seen = {};
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const cols = line.split("\t");
                    if (cols.length < 5) continue;
                    const file = cols[0];
                    if (seen[file]) continue; // user override wins over /etc/xdg/autostart
                    seen[file] = true;
                    list.push({
                        file: file,
                        name: cols[1] || file,
                        exec: cols[2] || "",
                        enabled: cols[3].trim() !== "true",
                        system: cols[4].trim() === "1"
                    });
                }
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.autostartApps = list;
            }
        }
        onExited: root.autostartLoading = false
    }

    // ---- User Systemd Services ----
    function refreshUserServices() {
        if (svcListProc.running) return;
        root.servicesLoading = true;
        svcListProc.running = true;
    }

    function controlUserService(unit: string, action: string) {
        if (!unit) return;
        Quickshell.execDetached(["timeout", "6", "systemctl", "--user", action, unit]);
        svcRefreshLater.restart();
    }

    function loadServiceJournal(unit: string) {
        if (!unit) return;
        root.serviceJournalUnit = unit;
        root.serviceJournalText = "Loading journal…";
        journalProc.command = ["timeout", "4", "journalctl", "--user", "-u", unit, "-n", "25", "--no-pager", "-o", "short-iso"];
        journalProc.running = true;
    }

    Timer {
        id: svcRefreshLater
        interval: 700
        onTriggered: root.refreshUserServices()
    }

    Process {
        id: svcListProc
        command: ["timeout", "4", "systemctl", "--user", "list-units", "--type=service", "--all", "--output=json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.servicesLoading = false;
                try {
                    const arr = JSON.parse(text.trim());
                    if (!Array.isArray(arr)) return;
                    const out = arr.map(u => ({
                        unit: u.unit || "",
                        load: u.load || "",
                        active: u.active || "",
                        sub: u.sub || "",
                        description: u.description || ""
                    }));
                    out.sort((a, b) => {
                        const aRun = a.active === "active" ? 1 : 0;
                        const bRun = b.active === "active" ? 1 : 0;
                        return (bRun - aRun) || a.unit.localeCompare(b.unit);
                    });
                    root.userServices = out;
                } catch (e) {}
            }
        }
        onExited: root.servicesLoading = false
    }

    Process {
        id: journalProc
        stdout: StdioCollector {
            onStreamFinished: root.serviceJournalText = text.trim() || "(no recent journal lines)"
        }
    }

    // ---- About / Hardware Summary ----
    function refreshAbout() {
        if (!aboutProc.running) aboutProc.running = true;
    }

    function copyAboutSummary() {
        const lines = [
            "OS: " + root.osName + (root.nixosGeneration ? (" (" + root.nixosGeneration + ")") : ""),
            "Host: " + root.hostname,
            "Kernel: " + root.kernel,
            "Hyprland: " + root.hyprlandVersion,
            "Quickshell: " + root.quickshellVersion,
            "CPU: " + root.cpuModel,
            "GPU: " + root.gpuModel,
            "Memory: " + root.ramTotal,
            "Disk (/): " + root.diskUsage,
            "Uptime: " + root.uptimeText
        ].join("\n");
        Quickshell.execDetached(["wl-copy", lines]);
    }

    Process {
        id: aboutProc
        command: [
            "sh", "-c",
            "os=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | tr -d '\"' | head -n1); " +
            "gen=$(basename \"$(readlink /nix/var/nix/profiles/system 2>/dev/null)\" 2>/dev/null); " +
            "kern=$(uname -r); " +
            "host=$(cat /etc/hostname 2>/dev/null || uname -n); " +
            "cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//'); " +
            "gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1 | cut -d: -f3- | sed 's/^ *//'); " +
            "ram=$(awk '/MemTotal/{printf \"%.1f GiB\", $2/1048576}' /proc/meminfo 2>/dev/null); " +
            "disk=$(df -h / 2>/dev/null | awk 'NR==2{print $3\" / \"$2\" (\"$5\")\"}'); " +
            "hypr=$(timeout 2 hyprctl version 2>/dev/null | head -n1 | sed 's/^Hyprland //'); " +
            "qsver=$(timeout 2 qs --version 2>/dev/null | head -n1); " +
            "up=$(uptime -p 2>/dev/null | sed 's/^up //'); " +
            "printf 'OS=%s\\nGEN=%s\\nKERN=%s\\nHOST=%s\\nCPU=%s\\nGPU=%s\\nRAM=%s\\nDISK=%s\\nHYPR=%s\\nQS=%s\\nUP=%s\\n' " +
            "  \"$os\" \"$gen\" \"$kern\" \"$host\" \"$cpu\" \"$gpu\" \"$ram\" \"$disk\" \"$hypr\" \"$qsver\" \"$up\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    const k = line.slice(0, eq).trim();
                    const v = line.slice(eq + 1).trim();
                    if (k === "OS" && v) root.osName = v;
                    else if (k === "GEN") root.nixosGeneration = v;
                    else if (k === "KERN") root.kernel = v;
                    else if (k === "HOST") root.hostname = v;
                    else if (k === "CPU") root.cpuModel = v;
                    else if (k === "GPU") root.gpuModel = v;
                    else if (k === "RAM") root.ramTotal = v;
                    else if (k === "DISK") root.diskUsage = v;
                    else if (k === "HYPR") root.hyprlandVersion = v;
                    else if (k === "QS") root.quickshellVersion = v;
                    else if (k === "UP") root.uptimeText = v;
                }
            }
        }
    }
}
