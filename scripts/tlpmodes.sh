#!/usr/bin/env bash

set_saver() {
    sudo tlp bat
    echo "low-power" | sudo tee /sys/firmware/acpi/platform_profile > /dev/null
    notify-send -i battery-low "Power Mode" "Switched to Power Saver (BAT Mode)"
}

set_balanced() {
    sudo tlp bat
    echo "balanced" | sudo tee /sys/firmware/acpi/platform_profile > /dev/null
    for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [ -f "$epp" ] && echo "balance_performance" | sudo tee "$epp" > /dev/null 2>&1
    done
    notify-send -i battery "Power Mode" "Switched to Balanced Mode"
}

set_performance() {
    sudo tlp ac
    echo "performance" | sudo tee /sys/firmware/acpi/platform_profile > /dev/null
    notify-send -i preferences-system-power "Power Mode" "Switched to Performance (AC Mode)"
}

# Normalize input argument to lowercase
target_mode=$(echo "$1" | tr '[:upper:]' '[:lower:]')

case "$target_mode" in
    low|l|saver|bat)
        set_saver
        ;;
    balanced|b|balance)
        set_balanced
        ;;
    power|p|perf|performance|ac)
        set_performance
        ;;
    "")
        current_mode=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null | tr -d '[:space:]')
        case "$current_mode" in
            "low-power")
                set_balanced
                ;;
            "balanced")
                set_performance
                ;;
            "performance"|*)
                set_saver
                ;;
        esac
        ;;
    *)
        notify-send -i dialog-error "Power Mode" "Invalid argument: '$1'\nValid: low (l), balanced (b), power (p)"
        echo "Usage: $0 [low|l | balanced|b | power|p]" >&2
        exit 1
        ;;
esac
