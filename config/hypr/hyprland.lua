-- Hyprland >= 0.55 Lua config (COSMIC-themed Quickshell desktop in ~/.config/quickshell).
-- `require` resolves relative to this file's directory.

HYPR = os.getenv("HOME") .. "/.config/hypr"
HCS_QS = "qs"   -- prefix for shell IPC calls in binds

hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2, vrr = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL U2412M 0FFXD4152LWL", mode = "1920x1200@59.9500", position = "320x-1200", scale = 1, vrr = 0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

require("conf.environment")
require("conf.autostart")
require("conf.looks")
require("conf.keybinds")
require("conf.rules")

hl.device({
    name = "ftcs0038:00-2808:0105-touchpad",
    natural_scroll = true,
    sensitivity = 0.03,
})

require("conf.scrolling") -- scrolling layout + touchpad gestures (comment out for dwindle)
