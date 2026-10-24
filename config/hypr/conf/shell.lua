-- Desktop shell (Quickshell, ~/.config/quickshell). Loaded last from hyprland.lua.
-- Every bind here uses a key combination that is free in the original config.
-- Shell features are triggered through Quickshell IPC (IpcHandler targets in shell/).

local qs = HCS_QS

-- Start the shell (bar, wallpaper, notifications, OSDs, launcher, lock).
-- The shell is also the polkit agent; the NixOS config keeps polkit-gnome out of Hyprland sessions.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
end)

-- Replaced old apps keep their original keys (see conf/keyboard.lua):
--   SUPER Space = launcher (was rofi), SUPER SHIFT C = clipboard (was rofi+cliphist),
--   SUPER L = power menu (was wlogout), SUPER SHIFT R = restart shell + reload (was hyprestart.sh).
-- New keys only for features that had no app before:

-- Notification center
hl.bind("SUPER + N", hl.dsp.exec_cmd(qs .. " ipc call notifications toggle"))
-- KDE Plasma-style Overview (workspaces & live window previews)
hl.bind("SUPER + Tab", hl.dsp.exec_cmd(qs .. " ipc call overview toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd(qs .. " ipc call overview toggle"))
-- Lock screen: goes through logind so hypridle's lock_cmd decides what locks (hyprlock for now).
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"))
-- Quick settings panel
hl.bind("SUPER + comma", hl.dsp.exec_cmd(qs .. " ipc call quicksettings toggle"))
-- Emoji picker (launcher in ":" mode): Enter types the emoji, Shift+Enter only copies
hl.bind("SUPER + period", hl.dsp.exec_cmd(qs .. " ipc call launcher emoji"))
-- Color picker: click a pixel, #RRGGBB is copied
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd(qs .. " ipc call picker color"))

-- Blur behind the shell's surfaces, like COSMIC's frosted panel.
hl.layer_rule({
    name = "hcs-blur",
    match = { namespace = "^(hcs-(bar|popup|launcher|overview|osd|toast|notifications|quicksettings|power))$" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.3,
})
