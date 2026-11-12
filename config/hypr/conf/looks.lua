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
        allow_tearing = true,
    },

    -- Do NOT force software cursors here. Hyprland 0.57/Aquamarine 0.16 clears
    -- the DRM cursor plane on DPMS off and does not re-upload it on DPMS on.
    -- scripts/reassert-cursor.sh re-applies the cursor on wake (wired up in
    -- hypridle.conf and the lock screen), so hardware cursors can stay enabled.

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
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        vrr = 2,
        focus_on_activate = true,          -- Focus app window on notification / XDG activation
        allow_session_lock_restore = true, -- Recover Quickshell WlSessionLock after restart
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
