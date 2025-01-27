#!/usr/bin/env bash

# Check the number of monitors
monitor_count=$(hyprctl monitors | grep -c "Monitor")

if [ "$monitor_count" -eq 1 ]; then
    # Suspend the system if there's only one monitor
    systemctl suspend
else
    # Disable eDP-1 monitor if there are multiple monitors
    hyprctl keyword monitor "eDP-1, disable"
fi

