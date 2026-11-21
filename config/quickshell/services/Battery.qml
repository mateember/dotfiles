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
        if (!isFinite(seconds) || seconds <= 0) return "";
        const totalMins = Math.max(1, Math.round(seconds / 60));
        const h = Math.floor(totalMins / 60), m = totalMins % 60;
        if (h > 0 && m > 0) return `${h} h ${m} min`;
        if (h > 0) return `${h} h`;
        return `${m} min`;
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
