pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Laptop battery via UPower. (Power profiles intentionally not used: the user runs TLP.)
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real percent: device?.percentage ?? 0    // 0..1
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery

    readonly property string icon: {
        if (full || (!onBattery && percent > 0.97)) return "battery_full";
        if (charging) {
            const steps = [20, 30, 50, 60, 80, 90];
            const p = percent * 100;
            for (const s of steps) if (p <= s) return "battery_charging_" + s;
            return "battery_charging_full";
        }
        if (percent > 0.95) return "battery_full";
        const bars = Math.max(0, Math.min(6, Math.floor(percent * 7)));
        return "battery_" + bars + "_bar";
    }

    function formatTime(seconds: real): string {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    readonly property string status: {
        if (full) return "Fully charged";
        if (charging) {
            const t = formatTime(device?.timeToFull ?? 0);
            return t ? `Charging, ${t} until full` : "Charging";
        }
        if (!onBattery) return "Plugged in, not charging";
        const t = formatTime(device?.timeToEmpty ?? 0);
        return t ? `${t} remaining` : "On battery";
    }
}
