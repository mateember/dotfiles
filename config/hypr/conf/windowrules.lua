-- Lua version of conf/windowrules.conf. Same rules, same order.
-- hyprlang `match:class ^(x)$` → match = { class = "^(x)$" }; `float on` → float = true;
-- `size (monitor_w*0.5) (monitor_h*0.6)` → size = "monitor_w*0.5 monitor_h*0.6".
local rule = hl.window_rule

-- -----------------------------------------------------
-- General Window Rules
-- -----------------------------------------------------

-- Focus Rofi immediately
rule({ match = { class = "^(rofi)$" }, stay_focused = true })

-- Quickshell standalone apps (opened from the Launcher `!` menu as FloatingWindows)
rule({ match = { class = [[^(org\.quickshell|quickshell)$]] }, float = true, center = true })
rule({ match = { title = "^(HCS — ).*" }, float = true, center = true })

-- Volume Control (40% width, 50% height)
rule({ match = { title = "^(Pipewire Volume Control)$" }, float = true, size = "monitor_w*0.5 monitor_h*0.6", center = true })
rule({ match = { title = "^(Volume Control)$" }, float = true, size = "monitor_w*0.4 monitor_h*0.5", center = true })

-- Stardew Valley & Grub
rule({ match = { class = "^(StardewModdingAPI)$" }, float = true })
rule({ match = { class = "^(grub-customizer)$" }, float = true })

-- -----------------------------------------------------
-- Dialogs & System Tools
-- -----------------------------------------------------

--  Desktop Portals, Share Pickers & File Pickers
rule({ match = { class = [[^(xdg-desktop-portal-.*|org\.freedesktop\.impl\.portal\.desktop\..*)$]] }, float = true, center = true, stay_focused = true })
rule({ match = { class = [[^(\.?hyprland-share-picker.*|org\.hyprland\.xdg-desktop-portal-hyprland)$]] }, float = true, center = true, stay_focused = true })
rule({ match = { title = "^(Select what to share|MainPicker)$" }, float = true, center = true, stay_focused = true })
rule({ match = { class = [[^(org\.freedesktop\.impl\.portal\.desktop\.(kde|cosmic))$]] }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })
rule({ match = { class = [[^(com\.system76\.(CosmicFilesDialog|CosmicPortal))$]] }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })
rule({ match = { title = "^(Rename)$" }, float = true, center = true })
-- Blueman Manager (50% width, 60% height)
rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6" })
rule({ match = { title = "^(overskride)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6" })
rule({ match = { title = "^(Bluetooth Devices)$" }, float = true })
rule({ match = { title = "^(Calendar)$" }, float = true, center = true, size = "monitor_w*0.7 monitor_h*0.8" })

-- Network & Connections
rule({ match = { class = "^(nm-connection-editor)$" }, float = true, center = true })
rule({ match = { class = "^(org.netrs.ui)$" }, float = true, center = true })
rule({ match = { class = "^(cmst)$" }, float = true, center = true })
rule({ match = { class = "^(org.nmrs.ui)$" }, float = true, center = true, size = "monitor_w*0.4 monitor_h*0.6" })

-- -----------------------------------------------------
-- Applications
-- -----------------------------------------------------

-- LACT
rule({ match = { class = "^(lact)$" }, float = true })

-- Cider (60% width, 70% height)
rule({ match = { title = "^(Cider)$" }, float = true, size = "monitor_w*0.6 monitor_h*0.7", center = true })

-- Calculator
rule({ match = { title = "^(KCalc)$" }, float = true })

-- -----------------------------------------------------
-- Picture-in-Picture
-- -----------------------------------------------------

-- Fixed Size (560x315) and Move (Bottom-Right minus 20px)
-- Using (monitor_w - window_w - 20) calculates the right edge position.
rule({
    match = { title = "^(Picture[- ]in[- ][Pp]icture)$" },
    float = true,
    pin = true,
    size = "560 315",
    move = "monitor_w-window_w-20 monitor_h-window_h-20",
    opacity = "1.0 override",
})

-- -----------------------------------------------------
-- XWayland Video Bridge
-- -----------------------------------------------------

rule({
    match = { class = "^(xwaylandvideobridge)$" },
    opacity = "0.0 override 0.0 override",
    no_anim = true,
    no_initial_focus = true,
    max_size = "1 1",
    no_blur = true,
})
--Matlab
rule({ match = { title = "^(Figures)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })
-- -----------------------------------------------------
-- Gaming & Idle
-- -----------------------------------------------------

rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
rule({ match = { title = "^(Fallout4)$" }, fullscreen = true })
rule({ match = { class = "^(steam_app_)$" }, fullscreen = true })
rule({ match = { class = "^(com.moonlight_stream.Moonlight)$" }, fullscreen = true })
rule({ match = { title = "^(Ultimate Chicken Horse)$" }, fullscreen = true })
