local rule = hl.window_rule

rule({ match = { class = "^(rofi)$" }, stay_focused = true })

-- Quickshell standalone apps (opened from Launcher `!` menu)
rule({ match = { class = [[^(org\.quickshell|quickshell)$]] }, float = true, center = true })
rule({ match = { title = "^(HCS — ).*" }, float = true, center = true, opacity = "1.0 override" })

rule({ match = { title = "^(Pipewire Volume Control)$" }, float = true, size = "monitor_w*0.5 monitor_h*0.6", center = true })
rule({ match = { title = "^(Volume Control)$" }, float = true, size = "monitor_w*0.4 monitor_h*0.5", center = true })

rule({ match = { class = "^(StardewModdingAPI)$" }, float = true })
rule({ match = { class = "^(grub-customizer)$" }, float = true })

-- Portals, pickers, system tools
rule({ match = { class = [[^(xdg-desktop-portal-.*|org\.freedesktop\.impl\.portal\.desktop\..*)$]] }, float = true, center = true, stay_focused = true })
rule({ match = { class = [[^(\.?hyprland-share-picker.*|org\.hyprland\.xdg-desktop-portal-hyprland)$]] }, float = true, center = true, stay_focused = true })
rule({ match = { title = "^(Select what to share|MainPicker)$" }, float = true, center = true, stay_focused = true })
rule({ match = { class = [[^(org\.freedesktop\.impl\.portal\.desktop\.(kde|cosmic))$]] }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })
rule({ match = { class = [[^(com\.system76\.(CosmicFilesDialog|CosmicPortal))$]] }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })
rule({ match = { title = "^(Rename)$" }, float = true, center = true })
rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6" })
rule({ match = { title = "^(overskride)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6" })
rule({ match = { title = "^(Bluetooth Devices)$" }, float = true })
rule({ match = { title = "^(Calendar)$" }, float = true, center = true, size = "monitor_w*0.7 monitor_h*0.8" })

rule({ match = { class = "^(nm-connection-editor)$" }, float = true, center = true })
rule({ match = { class = "^(org.netrs.ui)$" }, float = true, center = true })
rule({ match = { class = "^(cmst)$" }, float = true, center = true })
rule({ match = { class = "^(org.nmrs.ui)$" }, float = true, center = true, size = "monitor_w*0.4 monitor_h*0.6" })

rule({ match = { class = "^(lact)$" }, float = true })
rule({ match = { title = "^(Cider)$" }, float = true, size = "monitor_w*0.6 monitor_h*0.7", center = true })

-- Chromium/Brave extension pop-outs open with initialTitle "_crx_<id>" before the page title loads
rule({
    match = { initial_title = "^(_crx_.*)$" },
    float = true,
    center = true,
})
rule({
    match = { class = "^((brave|chrome|chromium)-[a-z]{32}-.*|[Bb]itwarden)$" },
    float = true,
    center = true,
})
rule({
    match = { title = "^(Bitwarden|Extension:.*)$" },
    float = true,
    center = true,
})

rule({ match = { title = "^(KCalc)$" }, float = true })

-- Picture-in-Picture
rule({
    match = { title = "^([Pp]icture[- ]in[- ][Pp]icture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = "560 315",
    move = "monitor_w-window_w-20 monitor_h-window_h-20",
    opacity = "1.0 override",
})
rule({
    match = { initial_title = "^([Pp]icture[- ]in[- ][Pp]icture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = "560 315",
    move = "monitor_w-window_w-20 monitor_h-window_h-20",
    opacity = "1.0 override",
})

-- Dynamic fallback for Chromium/Brave and Firefox on Wayland:
-- Extension pop-outs and Picture-in-Picture windows often set their title AFTER mapping,
-- which is too late for creation-time window rules (float, pin, size, move).
local pip_configured = {}

local function win_selector(w)
    local a = tostring(w.address or "")
    if not a:match("^0x") then a = "0x" .. a end
    return "address:" .. a
end

local function handle_dynamic_window(w)
    if not w then return end
    local t = w.title or ""
    local it = w.initial_title or ""
    local addr = win_selector(w)

    if t == "Bitwarden" or t:match("^Extension:") or it:match("^_crx_") then
        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
            hl.dispatch(hl.dsp.window.center())
        end
    elseif t:match("^[Pp]icture[- ]in[- ][Pp]icture$") and not pip_configured[addr] then
        pip_configured[addr] = true
        local mon = w.monitor or hl.get_active_monitor()
        local mw = mon and mon.width or 1920
        local mh = mon and mon.height or 1080
        local scale = (mon and mon.scale and mon.scale > 0) and mon.scale or 1
        local mx = mon and mon.x or 0
        local my = mon and mon.y or 0
        local lw = math.floor(mw / scale)
        local lh = math.floor(mh / scale)
        local pw, ph = 560, 315
        local px = mx + lw - pw - 20
        local py = my + lh - ph - 20

        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
        end
        if not w.pinned then
            hl.dispatch(hl.dsp.window.pin({ window = addr }))
        end
        hl.dispatch(hl.dsp.window.resize({ x = pw, y = ph, window = addr }))
        hl.dispatch(hl.dsp.window.move({ x = px, y = py, window = addr }))
    end
end

hl.on("window.open", handle_dynamic_window)
hl.on("window.title", handle_dynamic_window)
hl.on("window.close", function(w)
    if w and w.address then
        pip_configured[win_selector(w)] = nil
    end
end)

-- XWayland Video Bridge
rule({
    match = { class = "^(xwaylandvideobridge)$" },
    opacity = "0.0 override 0.0 override",
    no_anim = true,
    no_initial_focus = true,
    max_size = "1 1",
    no_blur = true,
})

rule({ match = { title = "^(Figures)$" }, float = true, center = true, size = "monitor_w*0.5 monitor_h*0.6", stay_focused = true })

-- Gaming & Idle
rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
rule({ match = { title = "^(Fallout4)$" }, fullscreen = true })
rule({ match = { class = "^(steam_app_)$" }, fullscreen = true })
rule({ match = { class = "^(com.moonlight_stream.Moonlight)$" }, fullscreen = true })
rule({ match = { title = "^(Ultimate Chicken Horse)$" }, fullscreen = true })

-- Layer Rules (Quickshell frosted glass blur)
hl.layer_rule({
    name = "hcs-blur",
    match = { namespace = "^(hcs-(bar|popup|launcher|overview|osd|toast|notifications|quicksettings|power))$" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.05,
})
