-- Lua version of conf/environment.conf.

hl.env("HYPRCURSOR_THEME", "BreezeX-Black")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "BreezeX-Black")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
-- env = XDG_MENU_PREFIX,arch-
-- env = XDG_MENU_PREFIX,plasma-
hl.env("TERM", "kitty")
hl.env("WLR_NO_HARDWARE_CURSORS", "0")
-- env = GDK_SCALE,2
-- env = GTK_SCALE,2
hl.env("GTK_USE_PORTAL", "1")
hl.env("BROWSER", "brave-origin") -- HCS: was "brave", which isn't installed
hl.env("NIXOS_OZONE_WL", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_IM_MODULE", "")
hl.env("GTK_IM_MODULE", "")
hl.env("XMODIFIERS", "")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Desktop shell: icon theme for Quickshell (COSMIC's icon theme). HCS_EMOJI_FILE (emoji picker list)
-- is set by the NixOS config.
hl.env("QS_ICON_THEME", "Pop")


hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
end)
