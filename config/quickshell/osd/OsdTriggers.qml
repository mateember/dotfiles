import QtQuick
import Quickshell
import qs
import qs.services

// Watches system state and shows an OSD (or a notification) when something changes,
// the way a desktop environment does. Changes made from an open popup don't trigger the
// OSD for that popup's own value (you already see it there).
Scope {
    id: root

    function popupOpen(name: string): bool { return Popups.current.startsWith(name + "@"); }

    // ---- volume / mute ----
    Connections {
        target: Audio
        function onVolumeChanged() {
            if (!root.popupOpen("volume")) Osd.show(Audio.icon, "Volume", Audio.muted ? 0 : Audio.volume, 1);
        }
        function onMutedChanged() {
            Osd.show(Audio.icon, Audio.muted ? "Muted" : "Volume", Audio.muted ? 0 : Audio.volume, 1);
        }
        function onMicMutedChanged() {
            Osd.show(Audio.micMuted ? "mic_off" : "mic", Audio.micMuted ? "Microphone muted" : "Microphone on", -1, 1);
        }
        function onSinkChanged() {
            if (Audio.sink) Osd.show("speaker", Audio.nodeName(Audio.sink), -1, 1);
        }
    }

    // ---- brightness ----
    Connections {
        target: Brightness
        function onChanged() {
            if (!root.popupOpen("display")) Osd.show("brightness_6", "Brightness", Brightness.value, 1);
        }
        function onKbdChanged() {
            if (!root.popupOpen("display"))
                Osd.show("keyboard", Brightness.kbdLevel > 0 ? "Keyboard backlight" : "Keyboard backlight off",
                         Brightness.kbdLevel > 0 ? Brightness.kbdLevel / Brightness.kbdMax : -1, 1);
        }
    }

    // ---- toggles ----
    Connections {
        target: Idle
        function onCaffeineChanged() { Osd.show("coffee", Idle.caffeine ? "Caffeine on: screen stays awake" : "Caffeine off", -1, 1); }
    }
    Connections {
        target: Notifs
        function onDndChanged() { Osd.show(Notifs.dnd ? "notifications_off" : "notifications", Notifs.dnd ? "Do not disturb on" : "Do not disturb off", -1, 1); }
    }
    Connections {
        target: Net
        function onWifiEnabledChanged() { Osd.show(Net.wifiEnabled ? "wifi" : "wifi_off", Net.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off", -1, 1); }
    }
    Connections {
        target: Bt
        function onEnabledChanged() { Osd.show(Bt.enabled ? "bluetooth" : "bluetooth_disabled", Bt.enabled ? "Bluetooth on" : "Bluetooth off", -1, 1); }
    }
    Connections {
        target: Hypr
        function onLayoutChanged() { Osd.show("view_quilt", "Layout: " + Hypr.layout, -1, 1); }
    }

    // ---- power ----
    Connections {
        target: Battery
        function onOnBatteryChanged() {
            if (!Battery.available) return;
            Osd.show(Battery.onBattery ? Battery.icon : "power", Battery.onBattery ? "On battery" : "Plugged in", Battery.percent, 1);
        }
        function onPercentChanged() {
            if (!Battery.onBattery || !Osd.ready) return;
            const p = Math.round(Battery.percent * 100);
            if (p === 20 || p === 10 || p === 5)
                Quickshell.execDetached(["notify-send", "-u", p <= 10 ? "critical" : "normal", "-i", "battery-caution",
                                         "-a", "Battery", "Battery low", p + "% remaining. Plug in the charger."]);
        }
    }
}
