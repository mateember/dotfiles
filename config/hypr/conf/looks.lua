-- Lua version of conf/looks.conf.

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 7,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(cb581aee)", "rgba(ffffffee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "dwindle",

        -- Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
        allow_tearing = true,
    },

    decoration = {
        rounding = 5,
        inactive_opacity = 0.75,

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        -- `pseudotile = true` was removed in Hyprland 0.55 (pseudotiling is always available, SUPER P)
        preserve_split = true, -- you probably want this
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0, -- Set to 0 to disable the anime mascot wallpapers
        vrr = 2,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

-- Animations (same as the original hyprlang `bezier` / `animation` lines)
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
--bezier = myBezier, 0.05,0.9,0.1,1.1

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
