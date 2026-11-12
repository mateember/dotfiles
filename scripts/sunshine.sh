#!/usr/bin/env bash

export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$(id -u)/hypr/ | head -n 1)

WIDTH=${SUNSHINE_CLIENT_WIDTH:-1920}
HEIGHT=${SUNSHINE_CLIENT_HEIGHT:-1080}
FPS=${SUNSHINE_CLIENT_FPS:-60}

# Place virtual display above-right of the 2880/2=1440px logical laptop screen
X_POS=1440
Y_POS=-500

case "$1" in
    "start")
        hyprctl output create headless REMOTE
        sleep 0.2
        hyprctl keyword monitor "REMOTE,${WIDTH}x${HEIGHT}@${FPS},${X_POS}x${Y_POS},1"
        # Software cursor required so Sunshine captures the pointer
        hyprctl keyword cursor:no_hardware_cursors true
        hyprctl dispatch focusmonitor REMOTE
        echo "Started: REMOTE monitor at ${X_POS}x${Y_POS} with Software Cursor enabled."
        ;;

    "stop")
        hyprctl output remove REMOTE
        hyprctl keyword monitor "eDP-1,2880x1800@120,0x0,2,vrr,1"
        hyprctl keyword cursor:no_hardware_cursors false
        echo "Stopped: REMOTE monitor removed and hardware cursor restored."
        ;;

    "vnc")
        hyprctl output create headless REMOTE
        sleep 0.2
        hyprctl keyword monitor "REMOTE,${WIDTH}x${HEIGHT}@${FPS},${X_POS}x${Y_POS},1"
        hyprctl dispatch focusmonitor REMOTE
        echo "Started: REMOTE monitor at ${X_POS}x${Y_POS} without Software Cursor enabled."
        ;;


    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
