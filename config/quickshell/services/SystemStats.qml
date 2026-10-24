pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU usage, CPU package temperature and RAM, read from /proc and /sys (no native API exists).
Singleton {
    id: root

    property real cpu: 0          // 0..1
    property real tempC: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property string tempPath: ""
    property int interval: 2000

    property var _prev: null

    function parseStat(text: string) {
        const f = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (root._prev) {
            const dt = total - root._prev.total;
            if (dt > 0) root.cpu = 1 - (idle - root._prev.idle) / dt;
        }
        root._prev = { idle, total };
    }

    function parseMem(text: string) {
        const get = k => Number((text.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) || [0, 0])[1]);
        const total = get("MemTotal"), avail = get("MemAvailable");
        root.memTotalGiB = total / 1048576;
        root.memUsedGiB = (total - avail) / 1048576;
    }

    FileView { id: stat; path: "/proc/stat"; onLoaded: root.parseStat(text()) }
    FileView { id: mem; path: "/proc/meminfo"; onLoaded: root.parseMem(text()) }
    FileView {
        id: temp
        path: root.tempPath
        printErrors: false
        onLoaded: root.tempC = Number(text()) / 1000
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
            if (root.tempPath !== "") temp.reload();
        }
    }
}
