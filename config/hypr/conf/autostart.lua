-- Lua version of conf/autostart.conf.
-- hyprlang `exec-once` → inside hl.on("hyprland.start"), runs once at startup.
-- hyprlang `exec` (every reload) → hl.on("hyprland.start") + hl.on("config.reloaded").
-- Changes vs. the original (marked HCS):
--   - waybar and dunst are replaced by the shell (started from conf/shell.lua).
--     Only one notification daemon can own org.freedesktop.Notifications.
--   - swww.sh is replaced by the shell's own wallpaper layer.
--   - kdeconnect-indicator added (tray icon).

hl.on("hyprland.start", function()
    -- Core Services
    -- HCS: hl.exec_cmd("waybar")
    -- HCS: hl.exec_cmd("dunst")
    hl.exec_cmd("hypridle")
    -- Session setup for a plain (non-UWSM) Hyprland session: import the display variables and start
    -- graphical-session.target, without which xdg-desktop-portal (xdg-open, screen sharing, file
    -- pickers) and everything wantedBy it never start. See scripts/session-target.sh.
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/session-target.sh start")

    -- exec-once = hyprpaper
    -- exec-once = waypaper --random

    -- Authentication & System Helpers
    -- exec-once = /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
    -- exec-once = /usr/lib/polkit-kde-authentication-agent-1
    -- exec-once = /run/current-system/sw/bin/kwalletd6
    -- exec-once = /usr/bin/kdeconnectd

    -- Clipboard & Applets
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("xembedsniproxy")
    -- HCS: KDE Connect tray icon (kdeconnectd itself is started by its XDG autostart / D-Bus).
    hl.exec_cmd("kdeconnect-indicator")
    -- exec-once = nm-applet
    -- exec-once = blueman-applet

    -- Environment & Portal Sync (Critical when not using UWSM)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
    -- exec-once = dbus-update-activation-environment --systemd --all
    -- exec-once = systemctl --user restart xdg-desktop-portal.service

    -- Scripts & Backgrounds
    -- exec-once = ~/.config/hyprland/start-in-tray.sh
    -- exec-once = ~/.scripts/mountrpi.sh

    -- Cleanup / Legacy Lines
    -- exec = sleep 5; nm-applet
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/session-target.sh stop")
end)

-- Screen / Color Management (original: `exec = hyprsunset`, i.e. at start and on every reload).
-- Done with events rather than a top-level call so `Hyprland --verify-config` doesn't run it.
local function sunset() hl.exec_cmd("hyprsunset") end
hl.on("hyprland.start", sunset)
hl.on("config.reloaded", sunset)
-- exec-once = hyprpaper

-- HCS: exec = ~/.config/hypr/scripts/swww.sh   (wallpaper is drawn by the shell)
