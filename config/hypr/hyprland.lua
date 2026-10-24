-- Hyprland config (Lua, Hyprland >= 0.55; hyprlang .conf is removed in 0.57).
-- Desktop shell: Quickshell config in ~/.config/quickshell (COSMIC-themed bar, launcher,
-- notifications, OSD, polkit agent, wallpaper). Ported from ~/hypr-cosmic-shell.
-- `require` resolves relative to this file's directory.

HYPR = os.getenv("HOME") .. "/.config/hypr"
HCS_QS = "qs"   -- prefix for shell IPC calls in binds (default config: ~/.config/quickshell)

-- #monitor=HDMI-A-1,1920x1080@144,0x0,1,2rr,2,bitdepth,10
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2, vrr = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL U2412M 0FFXD4152LWL", mode = "1920x1200@59.9500", position = "320x-1200", scale = 1, vrr = 0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

require("conf.keyboard")
require("conf.windowrules")
require("conf.autostart")
require("conf.looks")
require("conf.environment")
-- See https://wiki.hypr.land/Configuring/Keywords/ for more

hl.device({
    name = "ftcs0038:00-2808:0105-touchpad",
    natural_scroll = true,
    sensitivity = 0.03,
})
-- #workspace=1,monitor:HDMI-A-1,default:true

-- --- desktop shell + niri-style layout ---
require("conf.niri")    -- niri-style scrolling layout + touchpad gestures (comment out for dwindle)
require("conf.shell")
