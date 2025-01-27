#!/usr/bin/env bash

# Get battery percentage
BATTERY_PERCENTAGE=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null)
BATTERY_STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null)
# Nerd Font icons (adjust as needed)
ICON_HIGH="󱊣"    # Full battery
ICON_MEDIUM="󱊢"  # Medium battery
ICON_LOW="󱊡"     # Low battery
ICON_CRITICAL="󰂃" # Critical battery
ICON_CHARGING="󰂄"   # Charging

# Check if the battery percentage is available
if [ -z "$BATTERY_PERCENTAGE" ]; then
    echo "Battery:  Info not found."
    exit 1
fi

# Determine the icon based on battery percentage and charging status
if [ "$BATTERY_STATUS" == "Charging" ]; then
    ICON=$ICON_CHARGING
elif [ "$BATTERY_PERCENTAGE" -ge 80 ]; then
    ICON=$ICON_FULL
elif [ "$BATTERY_PERCENTAGE" -ge 40 ]; then
    ICON=$ICON_MEDIUM
elif [ "$BATTERY_PERCENTAGE" -ge 20 ]; then
    ICON=$ICON_LOW
else
    ICON=$ICON_CRITICAL
fi

# Output the battery status with the icon
echo "$ICON Battery: $BATTERY_PERCENTAGE% ($BATTERY_STATUS)"
