-- Lua version of conf/keyboard.conf. Every bind is kept; only the syntax changed.
-- hyprlang flag → Lua option: binde → repeating, bindr → release, bindm → mouse, bindl → locked.

--Keyboard settings

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

        sensitivity = -0.4, -- -1.0 - 1.0, 0 means no modification.
    },
})


--Keybinds

local mainMod = "SUPER"
local browser = "brave-origin" -- HCS: was "brave", which isn't installed
local term = "kitty"
local filemanager = "nautilus"

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(term))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- Exit: under UWSM (the NixOS session) stop it cleanly, otherwise exit Hyprland directly.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- HCS (user request): SUPER F toggles maximize (keeps bar and gaps). Was `fullscreen, 0`;
-- real fullscreen moved to SUPER SHIFT F (conf/niri.lua).
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

--bindr = $mainMod,SPACE ,exec, wofi --show drun -I -a -n -W 500 -H 376 -s ~/.config/wofi/themes/gruvbox.css
--bindr = $mainMod,SPACE ,exec, rofi -show drun
-- HCS: rofi replaced by the shell's launcher (same key, still on release). Was:
--   rofi -show drun -theme ~/.config/rofi/launcher.rasi
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(HCS_QS .. " ipc call launcher toggle"), { release = true })

-- HCS: hyprestart.sh restarted waybar/dunst + waypaper + `hyprctl reload`. Now: restart the shell
-- (through the project's flake, so package changes are picked up) and reload Hyprland.
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(HYPR .. "/scripts/restart-shell.sh --reload-hyprland"))

--bindr=SUPER, SUPER_L, exec, pkill wofi || wofi
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
-- HCS: wlogout replaced by the shell's power menu (same key).
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(HCS_QS .. " ipc call power toggle"))
--bind = $mainMod, B, exec, com.brave.Browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))

--Screenshot
-- Original used $altMod / $shiftMod, which Hyprland resolved to ALT / SHIFT.
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

--Clipboard
-- HCS: the rofi/cliphist picker (which had a 'cfish_greeting' paste typo) is replaced by the shell's
-- clipboard popup, same key.
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(HCS_QS .. " ipc call clipboard toggle"))

--function keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("xf86audiomute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("xf86audioplay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("F11", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("ALT + P", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("xf86audionext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("xf86audioprev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +10%"))

hl.bind(mainMod .. " + SHIFT + f23", hl.dsp.exec_cmd("wtype -k Control_R"))


-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
-- (hyprlang `movetoworkspace` follows the window, hence follow = true)
for i = 1, 10 do
    local key = i % 10 -- workspace 10 is on key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + CTRL + mouse:272", hl.dsp.window.resize(), { mouse = true })

--Lid
-- The original ran scripts/monitor_check.sh and `hyprctl keyword monitor ...`. In Lua mode
-- `hyprctl keyword` no longer takes hyprlang, so the same logic is written in Lua here.
hl.bind("switch:on:Lid Switch", function()
    -- monitor_check.sh: suspend if only one monitor, otherwise disable the laptop panel
    if #hl.get_monitors() == 1 then
        hl.exec_cmd("systemctl suspend")
    else
        hl.monitor({ output = "eDP-1", disabled = true })
    end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2, vrr = 2 })
end, { locked = true })
