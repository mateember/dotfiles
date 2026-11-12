hl.config({
    input = {
        kb_layout = "hu",
        kb_variant = "",
        kb_model = "",
        kb_options = "fkeys:basic_13-24",

        kb_rules = "",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = false,
        },

        sensitivity = -0.35, -- -1.0 to 1.0
	accel_profile = "flat",
    },
})

local mainMod = "SUPER"
local browser = "brave-origin"
local term = "kitty"
local filemanager = "nautilus"

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(term))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- Exit UWSM session cleanly when active, otherwise exit Hyprland directly
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- Maximize keeps bar and gaps; real fullscreen is SUPER SHIFT F (conf/scrolling.lua)
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Quickshell IPC
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(HCS_QS .. " ipc call launcher toggle"), { release = true })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(HYPR .. "/scripts/restart-shell.sh --reload-hyprland"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(HCS_QS .. " ipc call clipboard toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd(HCS_QS .. " ipc call notifications toggle"))
hl.bind("SUPER + Tab", hl.dsp.exec_cmd(HCS_QS .. " ipc call overview toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd(HCS_QS .. " ipc call overview toggle"))
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd(HCS_QS .. " ipc call power toggle"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd(HCS_QS .. " ipc call quicksettings toggle"))
hl.bind("SUPER + period", hl.dsp.exec_cmd(HCS_QS .. " ipc call launcher emoji"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd(HCS_QS .. " ipc call picker color"))
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd(HCS_QS .. " ipc call capture toggle"))

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))

hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("xf86audiomute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("xf86audioplay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("F11", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("ALT + P", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("xf86audionext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("xf86audioprev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +10%"))

hl.bind(mainMod .. " + SHIFT + f23", hl.dsp.exec_cmd("wtype -k Control_R"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

for i = 1, 10 do
    local key = i % 10 -- workspace 10 on key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + CTRL + mouse:272", hl.dsp.window.resize(), { mouse = true })

-- Lid switch: suspend if single monitor, otherwise disable laptop panel
hl.bind("switch:on:Lid Switch", function()
    if #hl.get_monitors() == 1 then
        hl.exec_cmd("systemctl suspend")
    else
        hl.monitor({ output = "eDP-1", disabled = true })
    end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2, vrr = 2 })
end, { locked = true })
