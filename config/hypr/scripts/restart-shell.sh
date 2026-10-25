#!/usr/bin/env bash
# Restart the desktop shell (Quickshell, ~/.config/quickshell). Bound to SUPER SHIFT R.
#   restart-shell.sh                     restart the shell
#   restart-shell.sh --reload-hyprland   also `hyprctl reload`
#
# Makes sure the old shell is gone before starting a new one: two instances at once fight over
# the bar, notifications and IPC, and the second one fails with
# 'module "qs.bar" is not installed'.
# The new shell is started by Hyprland (hyprctl dispatch), so it doesn't inherit this
# script's environment or restrictions.
set -u
pids() { pgrep -f '^/nix/store/[^ ]*/bin/quickshell( -p [^ ]*)?$'; }

timeout 3 qs kill >/dev/null 2>&1
for _ in $(seq 20); do [ -z "$(pids)" ] && break; sleep 0.1; done
[ -n "$(pids)" ] && kill $(pids) 2>/dev/null && sleep 0.5
[ -n "$(pids)" ] && kill -9 $(pids) 2>/dev/null

[ "${1:-}" = "--reload-hyprland" ] && timeout 5 hyprctl reload >/dev/null
timeout 5 hyprctl dispatch 'hl.dsp.exec_cmd("qs")' >/dev/null
