pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Laptop backlight (sysfs + brightnessctl) and external monitors (DDC/CI via ddcutil).
// Backlight changes are picked up from udev events, so key presses update the UI and OSD.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property bool available: max > 0
    readonly property real value: available ? current / max : 0

    // External monitors: [{ bus, name, value (0..1) }]. Empty without i2c access (see NIXOS_NOTES.md).
    property var externals: []

    signal changed()   // emitted on any backlight change (for the OSD)

    // ---- keyboard backlight (/sys/class/leds/*kbd_backlight*, levels 0..kbdMax) ----
    // The level isn't read back from the hardware (Fn-key changes aren't reported reliably).
    // The shell shows the level last chosen here, remembered across restarts.
    property string kbdDevice: ""
    property int kbdMax: 0
    readonly property int kbdLevel: kbdState.level
    readonly property bool kbdAvailable: kbdMax > 0
    signal kbdChanged()

    function setKbd(level: int) {
        const l = Math.max(0, Math.min(root.kbdMax, level));
        Quickshell.execDetached(["brightnessctl", "-q", "-d", root.kbdDevice, "set", String(l)]);
        if (l > 0) kbdState.lastOn = l;
        kbdState.level = l;
        kbdStore.setText(JSON.stringify({ level: kbdState.level, lastOn: kbdState.lastOn }));
        root.kbdChanged();
    }
    // Off → low → … → max → off (what the Fn key does on most laptops).
    function cycleKbd() { setKbd(root.kbdLevel >= root.kbdMax ? 0 : root.kbdLevel + 1); }
    // Off ↔ the last level that was on.
    function toggleKbd() { setKbd(root.kbdLevel > 0 ? 0 : Math.min(root.kbdMax, kbdState.lastOn)); }

    QtObject {
        id: kbdState
        property int level: 0
        property int lastOn: 1
    }
    FileView {
        id: kbdStore
        path: Quickshell.statePath("kbd-backlight.json")
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                kbdState.level = j.level ?? 0;
                kbdState.lastOn = j.lastOn ?? 1;
            } catch (e) {}
        }
    }

    function set(fraction: real) {
        const pct = Math.round(Math.max(0.01, Math.min(1, fraction)) * 100);
        Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"]);
    }

    function setExternal(bus: int, fraction: real) {
        const v = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
        Quickshell.execDetached(["ddcutil", "--bus", String(bus), "--noverify", "setvcp", "10", String(v)]);
        root.externals = root.externals.map(e => e.bus === bus ? Object.assign({}, e, { value: v / 100 }) : e);
    }

    function refreshExternals() {
        if (!ddc.running) ddc.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.device = text.trim() }
    }

    FileView {
        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        printErrors: false
        onLoaded: root.max = parseInt(text())
    }
    FileView {
        id: cur
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            if (v !== root.current) {
                root.current = v;
                root.changed();
            }
        }
    }

    Process {
        running: root.device !== ""
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: cur.reload() }
    }

    // One line per display: "<bus>\t<model>\t<current>\t<max>"
    Process {
        id: ddc
        command: ["sh", "-c", `
            ddcutil detect --brief 2>/dev/null | awk '/I2C bus:/{sub(".*i2c-","");bus=$0} /Monitor:/{split($0,a,":"); print bus "\\t" a[3]}' |
            while IFS="$(printf '\\t')" read -r bus model; do
              v=$(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null) || continue
              set -- $v; printf '%s\\t%s\\t%s\\t%s\\n' "$bus" "$model" "$4" "$5"
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.externals = text.split("\n").filter(l => l).map(l => {
                const p = l.split("\t");
                return { bus: Number(p[0]), name: p[1], value: Number(p[2]) / Math.max(1, Number(p[3])) };
            })
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*kbd_backlight* 2>/dev/null | head -n1 | xargs -r basename"]
        stdout: StdioCollector { onStreamFinished: root.kbdDevice = text.trim() }
    }
    FileView {
        path: root.kbdDevice ? `/sys/class/leds/${root.kbdDevice}/max_brightness` : ""
        printErrors: false
        onLoaded: root.kbdMax = parseInt(text())
    }
    Component.onCompleted: refreshExternals()
}
