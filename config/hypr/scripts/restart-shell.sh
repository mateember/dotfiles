#!/usr/bin/env bash
# Restart the desktop shell (Quickshell, ~/.config/quickshell). Bound to SUPER SHIFT R.
#   restart-shell.sh                     restart the shell
#   restart-shell.sh --reload-hyprland   also `hyprctl reload`
# The new shell is started by Hyprland (hyprctl dispatch), so it doesn't inherit this
# script's environment or restrictions.
qs kill >/dev/null 2>&1
[ "${1:-}" = "--reload-hyprland" ] && hyprctl reload >/dev/null
hyprctl dispatch 'hl.dsp.exec_cmd("qs")' >/dev/null
