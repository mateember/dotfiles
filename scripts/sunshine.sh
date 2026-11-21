#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hypr_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
    for sock in "$hypr_dir"/*/.socket.sock; do
        [ -S "$sock" ] || continue
        HYPRLAND_INSTANCE_SIGNATURE="$(basename "$(dirname "$sock")")"
        export HYPRLAND_INSTANCE_SIGNATURE
        break
    done
fi

WIDTH="${SUNSHINE_CLIENT_WIDTH:-1920}"
HEIGHT="${SUNSHINE_CLIENT_HEIGHT:-1080}"
FPS="${SUNSHINE_CLIENT_FPS:-60}"

[[ "$WIDTH" =~ ^[0-9]+$ ]] || WIDTH=1920
[[ "$HEIGHT" =~ ^[0-9]+$ ]] || HEIGHT=1080
[[ "$FPS" =~ ^[0-9]+$ ]] || FPS=60

# Place virtual display above-right of the 2880/2=1440px logical laptop screen
X_POS=1440
Y_POS=-500

case "${1:-}" in
    "start")
        timeout 3 hyprctl output create headless REMOTE
        sleep 0.2
        timeout 3 hyprctl eval "hl.monitor({ output = \"REMOTE\", mode = \"${WIDTH}x${HEIGHT}@${FPS}\", position = \"${X_POS}x${Y_POS}\", scale = 1 })"
        # Software cursor required so Sunshine captures the pointer
        timeout 3 hyprctl eval 'hl.config({ cursor = { no_hardware_cursors = 1 } })'
        timeout 3 hyprctl dispatch 'hl.dsp.focus({ monitor = "REMOTE" })'
        echo "Started: REMOTE monitor at ${X_POS}x${Y_POS} with Software Cursor enabled."
        ;;

    "stop")
        timeout 3 hyprctl output remove REMOTE || true
        timeout 3 hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2, vrr = 1 })'
        timeout 3 hyprctl eval 'hl.config({ cursor = { no_hardware_cursors = 0 } })'
        echo "Stopped: REMOTE monitor removed and hardware cursor restored."
        ;;

    "vnc")
        timeout 3 hyprctl output create headless REMOTE
        sleep 0.2
        timeout 3 hyprctl eval "hl.monitor({ output = \"REMOTE\", mode = \"${WIDTH}x${HEIGHT}@${FPS}\", position = \"${X_POS}x${Y_POS}\", scale = 1 })"
        timeout 3 hyprctl dispatch 'hl.dsp.focus({ monitor = "REMOTE" })'
        echo "Started: REMOTE monitor at ${X_POS}x${Y_POS} without Software Cursor enabled."
        ;;

    *)
        echo "Usage: $0 {start|stop|vnc}" >&2
        exit 1
        ;;
esac
