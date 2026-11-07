-- Autostart services and desktop shell.
-- `hl.on("hyprland.start")` runs once at startup (like `exec-once`).
-- `hl.on("hyprland.start")` + `hl.on("config.reloaded")` runs at start and on reload (like `exec`).

hl.on("hyprland.start", function()
    -- Desktop shell (bar, wallpaper, notifications, OSDs, launcher, polkit agent)
    hl.exec_cmd("qs")

    -- Idle daemon
    hl.exec_cmd("hypridle")

    -- Clipboard & tray applets
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("xembedsniproxy")
    hl.exec_cmd("kdeconnect-indicator")
end)

-- Screen / Color Management (runs at start and on every reload).
-- Done with events rather than a top-level call so `Hyprland --verify-config` doesn't run it.
local function sunset() hl.exec_cmd("hyprsunset") end
hl.on("hyprland.start", sunset)
hl.on("config.reloaded", sunset)
