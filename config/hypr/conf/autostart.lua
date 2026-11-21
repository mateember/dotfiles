-- Autostart services and desktop shell.
-- `hl.on("hyprland.start")` runs once at startup (like `exec-once`).
-- `hl.on("hyprland.start")` + `hl.on("config.reloaded")` runs at start and on reload (like `exec`).

hl.on("hyprland.start", function()
    -- Desktop shell (bar, wallpaper, notifications, OSDs, launcher, polkit agent)
    hl.exec_cmd("qs")

    -- Idle daemon: hypridle runs as a systemd user service (services.hypridle in ~/Nix).

    -- Clipboard watchers are managed directly by Quickshell (services/Clipboard.qml)
    -- so Pause History and Bitwarden/password-manager secret hygiene work natively.
    hl.exec_cmd("kdeconnect-indicator")
end)

-- Screen / Color Management (runs at start and on every reload).
-- Done with events rather than a top-level call so `Hyprland --verify-config` doesn't run it.
local function sunset() hl.exec_cmd("sh -c 'pgrep -x hyprsunset >/dev/null || exec hyprsunset'") end
hl.on("hyprland.start", sunset)
hl.on("config.reloaded", sunset)
