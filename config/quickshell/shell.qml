//@ pragma UseQApplication

// Desktop shell entry point (COSMIC-themed). Started by ~/.config/hypr/conf/autostart.lua (`qs`).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.launcher
import qs.wallpaper
import qs.notifications
import qs.osd
import qs.polkit
import qs.quicksettings
import qs.services

ShellRoot {
    // Singletons are created lazily; touch the ones that own IPC targets or system hooks
    // so they exist from startup (picker, wallpaper, notifications server, weather).
    readonly property var _eager: [ColorPicker, Wallpapers, Notifs, Emoji, PowerProfile, BarConfig, OpacityConfig, WeatherConfig, Weather, Hypr, Recorder, Privacy, Storage, WidgetHistory]

    // Wallpaper slideshow, one surface per screen (background layer).
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    // One bar per screen; follows monitors being plugged/unplugged.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {}
    Overview {}
    CaptureOverlay {}
    BarSettingsWindow {}
    OpacitySettingsWindow {}
    Toasts {}
    OsdWindow {}
    OsdTriggers {}
    PolkitPrompt {}
    // The lock screen is a separate Quickshell instance: lock.qml, started by hypr/scripts/lock.sh.
    QuickSettings {}

    // Open bar popups from keybinds/scripts, on the focused monitor:
    //   qs ipc call bar toggle volume
    // Popup names: clipboard weather calendar display layout media volume
    //              bluetooth network battery notifications power
    IpcHandler {
        target: "bar"
        function toggle(name: string): void {
            const screen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            Popups.toggle(name + "@" + screen);
        }
        function openWindow(name: string): void {
            const screen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            Popups.openWindow(name + "@" + screen);
        }
        function back(): void { WidgetHistory.backFromPopup(); }
        function close(): void { Popups.close(); }
    }

    // Keybind IPC targets (hypr/conf/keybinds.lua)
    IpcHandler {
        target: "clipboard"
        function toggle(): void { Popups.toggle("clipboard@" + (Hyprland.focusedMonitor?.name ?? "")); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { Popups.toggle("notifications@" + (Hyprland.focusedMonitor?.name ?? "")); }
    }
    // qs ipc call kbd cycle|toggle|set <level>
    IpcHandler {
        target: "kbd"
        function cycle(): void { Brightness.cycleKbd(); }
        function toggle(): void { Brightness.toggleKbd(); }
        function set(level: int): void { Brightness.setKbd(level); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { Popups.toggle("power@" + (Hyprland.focusedMonitor?.name ?? "")); }
    }
}
