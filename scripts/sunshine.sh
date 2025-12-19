#!/usr/bin/env bash

# 1. Help hyprctl find your active Hyprland session
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$(id -u)/hypr/ | head -n 1)

# 2. Get variables from Sunshine (with defaults)
WIDTH=${SUNSHINE_CLIENT_WIDTH:-1920}
HEIGHT=${SUNSHINE_CLIENT_HEIGHT:-1080}
FPS=${SUNSHINE_CLIENT_FPS:-60}

# 3. Position Calculation
# Laptop logical width (2880 / 2) = 1440
# X_POS = 1440 (directly to the right)
# Y_POS = -500 (shifted "up" above the laptop screen's top edge)
X_POS=1440
Y_POS=-500

case "$1" in
    "start")
        # A. Create the headless monitor
        hyprctl output create headless REMOTE
        sleep 0.2
        
        # B. Position the monitor (Right and Up)
        # Format: Name, Res@FPS, XxY, Scale
        hyprctl keyword monitor "REMOTE,${WIDTH}x${HEIGHT}@${FPS},${X_POS}x${Y_POS},1"
        
        # C. Fix: Force Software Cursor so Sunshine can see it
        hyprctl keyword cursor:no_hardware_cursors true
        
        # D. Optional: Focus the new monitor immediately
        hyprctl dispatch focusmonitor REMOTE
        
        echo "Started: REMOTE monitor at ${X_POS}x${Y_POS} with Software Cursor enabled."
        ;;

    "stop")
        # A. Remove the virtual monitor
        hyprctl output remove REMOTE
        
        # B. Restore Laptop Monitor settings
        hyprctl keyword monitor "eDP-1,2880x1800@120,0x0,2,vrr,1"
        
        # C. Restore Hardware Cursor for better performance
        hyprctl keyword cursor:no_hardware_cursors false
        
        echo "Stopped: REMOTE monitor removed and hardware cursor restored."
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
