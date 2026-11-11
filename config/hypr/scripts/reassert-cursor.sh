#!/bin/sh
# Hyprland 0.57 / Aquamarine 0.16 clears the DRM cursor plane when an output is
# disabled (DPMS off) and does not re-upload the cursor when the output is
# re-enabled. The pointer then stays invisible until something requests a new
# cursor shape (crossing into a widget with a different cursor, unlocking, or a
# cursor theme re-apply). Pure pointer motion only updates the cursor position
# and does not repopulate the plane. This is most noticeable on the static
# Quickshell lock screen after the idle blank.
#
# Re-applying the cursor theme forces PointerManager to rebuild and re-upload
# the cursor buffer, so the cursor is visible immediately on wake.
#
# Called from hypridle (on-resume / after_sleep_cmd) and from the lock screen
# before it turns the display back on. Theme/size come from conf/environment.lua.
exec timeout 3 hyprctl setcursor "${HYPRCURSOR_THEME:-BreezeX-Black}" "${HYPRCURSOR_SIZE:-24}" >/dev/null 2>&1
