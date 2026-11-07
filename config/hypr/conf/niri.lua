-- Niri-style workflow on Hyprland's built-in "scrolling" layout (Hyprland >= 0.55).
-- Loaded from hyprland.lua after looks.lua (overrides general.layout). To go back to dwindle,
-- comment out `require("conf.niri")` there, or toggle the layout from the bar.
--
-- Model (like niri): every window opens in a new COLUMN on an endless horizontal strip;
-- columns can hold several windows stacked vertically; WORKSPACES are stacked vertically
-- per monitor, and there's always a fresh empty one below the last.
--
-- All original binds are kept. Niri-style binds below only use keys that were free.
-- Niri's Mod+Minus / Mod+Equal / Mod+[ / Mod+] are on the same physical keys of the hu layout:
--   ü / ó (right of ö, top row) and ő / ú (right of P).

local M = "SUPER"
local layout = hl.dsp.layout

hl.config({
    general = { layout = "scrolling" },

    scrolling = {
        column_width = 1.0,                            -- most apps open full width (user choice);
                                                       -- terminals + file managers get 1/2 (rules below)
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",  -- niri preset-column-widths (SUPER R cycles)
        fullscreen_on_one_column = false,              -- niri keeps a lone window at its column width
        focus_fit_method = 1,                          -- scroll only as far as needed to show the focused column
                                                       -- (a strip narrower than the screen is shown centered)
        follow_focus = true,
        wrap_focus = false,                            -- niri doesn't wrap around at the strip ends
        wrap_swapcol = false,
        direction = "right",
    },

    gestures = {
        workspace_swipe_create_new = true,             -- swiping past the last workspace makes a new one
        workspace_swipe_direction_lock = true,
        scrolling = {
            move_snap_to_grid = true,                  -- touchpad scrolling settles on column edges
        },
    },
})

------------------------------------------------------------------------
-- Column widths per app
------------------------------------------------------------------------
-- Apps can't maximize themselves (kitty restores a maximized state on start, which made it
-- ignore the half-width rule). Use SUPER F to maximize instead.
hl.window_rule({ name = "no-self-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Terminals and file managers open at half width; everything else takes the full width.
-- Terminals (kitty, COSMIC Terminal, foot, Alacritty, WezTerm, GNOME Console) and
-- file managers (Thunar, COSMIC Files, Nautilus, Dolphin)
hl.window_rule({
    name = "half-width-terminals-and-files",
    match = { class = [[^(kitty|com\.system76\.CosmicTerm|foot|Alacritty|org\.wezfurlong\.wezterm|org\.gnome\.Console|[Tt]hunar|com\.system76\.CosmicFiles|org\.gnome\.Nautilus|org\.kde\.dolphin)$]] },
    scrolling_width = 0.5,
})

-- Workspaces slide vertically, like niri.
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidevert" })

------------------------------------------------------------------------
-- Touchpad
------------------------------------------------------------------------
-- 3 fingers left/right: scroll the strip (1:1, snaps to columns)
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
-- 3 fingers up/down: previous/next workspace on this monitor
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

-- 4 fingers up/down: bring Overview up / down (follows fingers 1:1 via socket2 event)
local overview_dy = 0
hl.gesture({
    fingers = 4,
    direction = "vertical",
    disable_inhibit = true,
    action = {
        start = function(e)
            overview_dy = -e.delta.y
            hl.dispatch(hl.dsp.event("hcs_overview:start:" .. string.format("%.1f", overview_dy)))
        end,
        update = function(e)
            overview_dy = overview_dy - e.delta.y
            hl.dispatch(hl.dsp.event("hcs_overview:update:" .. string.format("%.1f", overview_dy)))
        end,
        finish = function(e)
            hl.dispatch(hl.dsp.event("hcs_overview:finish:" .. (e.cancelled and "cancel" or string.format("%.1f", overview_dy))))
        end,
    },
})

------------------------------------------------------------------------
-- Keyboard / mouse (niri default bindings, on keys that were free)
------------------------------------------------------------------------
-- SUPER ←/→/↑/↓ (your original movefocus binds) already move between columns/windows and,
-- at the strip's edge, to the next monitor, which is niri's focus-column-or-monitor.

-- Move the focused column left/right, the window up/down inside its column
hl.bind(M .. " + CTRL + left",  layout("swapcol l"))
hl.bind(M .. " + CTRL + right", layout("swapcol r"))
hl.bind(M .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(M .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }))

-- Focus / move to other monitors
hl.bind(M .. " + SHIFT + left",  hl.dsp.focus({ monitor = "l" }))
hl.bind(M .. " + SHIFT + right", hl.dsp.focus({ monitor = "r" }))
hl.bind(M .. " + SHIFT + up",    hl.dsp.focus({ monitor = "u" }))
hl.bind(M .. " + SHIFT + down",  hl.dsp.focus({ monitor = "d" }))
hl.bind(M .. " + SHIFT + CTRL + left",  hl.dsp.window.move({ monitor = "l", follow = true }))
hl.bind(M .. " + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r", follow = true }))
hl.bind(M .. " + SHIFT + CTRL + up",    hl.dsp.window.move({ monitor = "u", follow = true }))
hl.bind(M .. " + SHIFT + CTRL + down",  hl.dsp.window.move({ monitor = "d", follow = true }))

-- Vertical workspaces on this monitor ("r" includes empty ones, so going down past the
-- last workspace opens a new empty one, like niri)
hl.bind(M .. " + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(M .. " + Page_Up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(M .. " + U",         hl.dsp.focus({ workspace = "r+1" }))
hl.bind(M .. " + I",         hl.dsp.focus({ workspace = "r-1" }))
hl.bind(M .. " + CTRL + Page_Down", hl.dsp.window.move({ workspace = "r+1", follow = true }))
hl.bind(M .. " + CTRL + Page_Up",   hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(M .. " + CTRL + U",         hl.dsp.window.move({ workspace = "r+1", follow = true }))
hl.bind(M .. " + CTRL + I",         hl.dsp.window.move({ workspace = "r-1", follow = true }))

-- Column width: cycle presets, ±10 %, maximize, center
hl.bind(M .. " + R",          layout("colresize +conf"))
hl.bind(M .. " + CTRL + R",   layout("colresize -conf"))
hl.bind(M .. " + udiaeresis", layout("colresize -0.1"))   -- niri Mod+Minus
hl.bind(M .. " + oacute",     layout("colresize +0.1"))   -- niri Mod+Equal
hl.bind(M .. " + CTRL + C",   layout("center"))

-- SUPER F toggles between full width (1.0) and the window's previous width (or 0.5 default)
-- in scrolling layout (or falls back to traditional maximize in other layouts / floating).
local prev_widths = {}

local function toggle_width()
    local w = hl.get_active_window()
    if not w then return end

    if w.floating or hl.get_config("general:layout") ~= "scrolling" then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        return
    end

    if w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        return
    end

    local mon = hl.get_active_monitor()
    local mon_w = (mon and mon.scale and mon.scale > 0) and (mon.width / mon.scale) or 1440
    local is_full = (w.size.x / mon_w) >= 0.85

    if is_full then
        -- Window is currently full width.
        -- Shrink to previous unmaximized size, or default to 0.5 if it opened full width.
        local target = prev_widths[w.address] or 0.5
        if target >= 0.85 or target < 0.2 then target = 0.5 end
        prev_widths[w.address] = target
        hl.dispatch(hl.dsp.layout(string.format("colresize %.2f", target)))
    else
        -- Window is currently at a partial width (0.5, 0.6, 0.7, etc.).
        -- Read its actual size right now before maximizing.
        local ratio = math.floor(((w.size.x + 18) / mon_w) * 100 + 0.5) / 100
        prev_widths[w.address] = ratio
        hl.dispatch(hl.dsp.layout("colresize 1.0"))
    end
end

_G.toggle_width = toggle_width

hl.unbind(M .. " + F")
hl.bind(M .. " + F", toggle_width)

-- Real fullscreen (SUPER + SHIFT + F), like niri's Mod+Shift+F.
hl.bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Pull the next window into this column / push a window out into its own column
hl.bind(M .. " + odoubleacute", layout("consume_or_expel prev"))  -- niri Mod+[
hl.bind(M .. " + uacute",       layout("consume_or_expel next"))  -- niri Mod+]

-- SUPER + SHIFT + wheel scrolls through columns (SUPER + wheel still switches workspaces)
hl.bind(M .. " + SHIFT + mouse_down", layout("focus r"))
hl.bind(M .. " + SHIFT + mouse_up",   layout("focus l"))
