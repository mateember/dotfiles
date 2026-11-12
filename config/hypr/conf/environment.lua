hl.env("HYPRCURSOR_THEME", "BreezeX-Black")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "BreezeX-Black")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("TERM", "kitty")
-- Hardware cursors stay enabled; scripts/reassert-cursor.sh handles the DPMS wake cursor bug.
hl.env("GTK_USE_PORTAL", "1")
hl.env("BROWSER", "brave-origin")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_IM_MODULE", "")
hl.env("GTK_IM_MODULE", "")
hl.env("XMODIFIERS", "")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- NixOS runs Hyprland through a cap_sys_nice wrapper (programs.hyprland). glibc treats that like a
-- setuid program and removes TZDIR from its environment, so apps it starts couldn't find the time
-- zone files (GNOME Calendar aborted with "tz != NULL"). Put it back for everything Hyprland starts.
-- (UWSM's own environment files can't help here: the variable is dropped from Hyprland's process
-- after they are applied, so it has to be set from inside the Hyprland config.)
hl.env("TZDIR", "/etc/zoneinfo")

-- Desktop shell: icon theme for Quickshell (COSMIC's icon theme). HCS_EMOJI_FILE (emoji picker list)
-- is set by the NixOS config.
hl.env("QS_ICON_THEME", "Pop")
