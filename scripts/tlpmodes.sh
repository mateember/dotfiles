#!/usr/bin/env bash

# Get the current power mode (this could be an output of some system command, e.g., cat /sys/class/power_supply/BAT0/status)
current_mode=$(cat /sys/firmware/acpi/platform_profile)  # Adjust this path based on your system's configuration

if [[ "$current_mode" == "low-power" ]]; then
    sudo tlp ac
    notify-send "Switching to performance mode"
elif [[ "$current_mode" == "performance" ]]; then
    sudo tlp start
    notify-send "Switching to automatic mode"
else
    notify-send "Unknown power mode: $current_mode"
fi

