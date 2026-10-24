//@ pragma UseQApplication

// Desktop shell entry point (COSMIC-themed). Started by ~/.config/hypr/conf/shell.lua (`qs`).
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
    // so they exist from startup (picker, wallpaper, notifications server).
    readonly property var _eager: [ColorPicker, Wallpapers, Notifs, Emoji, PowerProfile]

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
    Toasts {}
    OsdWindow {}
    OsdTriggers {}
    PolkitPrompt {}
    QuickSettings {}

    // Open bar popups from keybinds/scripts, on the focused monitor:
    //   qs -p <root>/shell ipc call bar toggle volume
    // Popup names: clipboard weather calendar display layout media volume
    //              bluetooth network battery notifications power
    IpcHandler {
        target: "bar"
        function toggle(name: string): void {
            const screen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            Popups.toggle(name + "@" + screen);
        }
        function close(): void { Popups.close(); }
    }

    // Targets used by the binds in hypr/conf/shell.lua.
    IpcHandler {
        target: "clipboard"
        function toggle(): void { Popups.toggle("clipboard@" + (Hyprland.focusedMonitor?.name ?? "")); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { Popups.toggle("notifications@" + (Hyprland.focusedMonitor?.name ?? "")); }
    }
    // qs -p <root>/shell ipc call kbd cycle|toggle|set <level>
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
