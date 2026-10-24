pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Removable USB / SD drive detection, automounting, and safe ejection via udisksctl.
Singleton {
    id: root

    property var drives: []
    property bool autoMount: true
    property var knownPaths: ({})
    property bool initialized: false

    readonly property int count: drives.length
    readonly property int mountedCount: drives.filter(d => d.mounted).length
    readonly property string scriptPath: Quickshell.shellPath("scripts/hardware-status.py")

    function refresh() {
        if (!scanProc.running) scanProc.running = true;
    }

    function mount(path: string, notify: bool) {
        if (!path) return;
        Quickshell.execDetached([
            "sh", "-c",
            'udisksctl mount -b "$1" --no-user-interaction >/dev/null 2>&1 && ' +
            'if [ "$2" = "1" ]; then notify-send -a "Removable Storage" -i drive-removable-media "USB Drive Mounted" "$3"; fi',
            "sh", path, notify ? "1" : "0", path
        ]);
        delayedRefresh.restart();
    }

    function unmount(path: string) {
        if (!path) return;
        Quickshell.execDetached([
            "sh", "-c",
            'udisksctl unmount -b "$1" --no-user-interaction >/dev/null 2>&1 && ' +
            'notify-send -a "Removable Storage" -i drive-removable-media "Drive Unmounted" "$1 can now be safely removed"',
            "sh", path
        ]);
        delayedRefresh.restart();
    }

    function eject(path: string, diskPath: string) {
        if (!path) return;
        const dp = diskPath || path;
        Quickshell.execDetached([
            "sh", "-c",
            'udisksctl unmount -b "$1" --no-user-interaction >/dev/null 2>&1 || true; ' +
            'udisksctl power-off -b "$2" --no-user-interaction >/dev/null 2>&1 || true; ' +
            'notify-send -a "Removable Storage" -i media-eject "Safe to Remove" "$1 has been ejected"',
            "sh", path, dp
        ]);
        delayedRefresh.restart();
    }

    function openInFiles(mountpoint: string) {
        if (!mountpoint) return;
        Quickshell.execDetached(["xdg-open", mountpoint]);
    }

    Timer {
        id: delayedRefresh
        interval: 900
        onTriggered: root.refresh()
    }

    // Event-driven block device monitor via udevadm (zero polling overhead)
    Process {
        id: udevMon
        running: true
        command: ["udevadm", "monitor", "--subsystem-match=block", "--udev"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("UDEV")) delayedRefresh.restart();
            }
        }
    }

    Component.onCompleted: root.refresh()

    Process {
        id: scanProc
        command: ["python3", root.scriptPath, "storage"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text.trim());
                    if (!Array.isArray(list)) return;
                    const nextKnown = {};
                    for (const d of list) {
                        nextKnown[d.path] = true;
                        if (root.initialized && !root.knownPaths[d.path]) {
                            // Newly plugged removable drive!
                            if (root.autoMount && !d.mounted) {
                                root.mount(d.path, true);
                            } else {
                                Quickshell.execDetached([
                                    "notify-send", "-a", "Removable Storage", "-i", "drive-removable-media",
                                    "USB Drive Connected", `${d.label} (${d.size})`
                                ]);
                            }
                        }
                    }
                    root.knownPaths = nextKnown;
                    root.initialized = true;
                    root.drives = list;
                } catch (e) {}
            }
        }
    }
}
