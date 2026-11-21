#!/usr/bin/env bash
set -u

notify_err() {
    notify-send -u critical -i dialog-error "Power Mode" "$1" 2>/dev/null || true
    echo "tlpmodes: $1" >&2
}

# Prefer the immutable root-owned NixOS helper (/nix/store/.../bin/hcs-tlp-mode) when installed.
run_privileged() {
    local mode="$1"
    local helper
    if helper="$(command -v hcs-tlp-mode 2>/dev/null)"; then
        sudo -n "$helper" "$mode"
        return $?
    fi
    case "$mode" in
        low)
            sudo -n tlp bat >/dev/null && \
            printf 'low-power\n' | sudo -n tee /sys/firmware/acpi/platform_profile >/dev/null
            ;;
        balanced)
            sudo -n tlp bat >/dev/null && \
            printf 'balanced\n' | sudo -n tee /sys/firmware/acpi/platform_profile >/dev/null || return 1
            for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -f "$epp" ] && { printf 'balance_performance\n' | sudo -n tee "$epp" >/dev/null 2>&1 || true; }
            done
            ;;
        performance)
            sudo -n tlp ac >/dev/null && \
            printf 'performance\n' | sudo -n tee /sys/firmware/acpi/platform_profile >/dev/null
            ;;
        auto)
            sudo -n tlp start >/dev/null
            ;;
        *)
            return 2
            ;;
    esac
}

set_saver() {
    if ! run_privileged low; then
        notify_err "Failed to switch to Power Saver (check sudoers / hcs-tlp-mode)"
        exit 1
    fi
    notify-send -i battery-low "Power Mode" "Switched to Power Saver (BAT Mode)" 2>/dev/null || true
}

set_balanced() {
    if ! run_privileged balanced; then
        notify_err "Failed to switch to Balanced Mode (check sudoers / hcs-tlp-mode)"
        exit 1
    fi
    notify-send -i battery "Power Mode" "Switched to Balanced Mode" 2>/dev/null || true
}

set_performance() {
    if ! run_privileged performance; then
        notify_err "Failed to switch to Performance Mode (check sudoers / hcs-tlp-mode)"
        exit 1
    fi
    notify-send -i preferences-system-power "Power Mode" "Switched to Performance (AC Mode)" 2>/dev/null || true
}

set_auto() {
    if ! run_privileged auto; then
        notify_err "Failed to switch to Automatic TLP mode (check sudoers / hcs-tlp-mode)"
        exit 1
    fi
    active=$(tr -d '[:space:]' < /sys/firmware/acpi/platform_profile 2>/dev/null || true)
    notify-send -i preferences-system-power "Power Mode" "Switched to Automatic (${active:-tlp})" 2>/dev/null || true
}

target_mode=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')

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
    auto|a|reset)
        set_auto
        ;;
    "")
        current_mode=$(tr -d '[:space:]' < /sys/firmware/acpi/platform_profile 2>/dev/null || true)
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
        notify-send -i dialog-error "Power Mode" $'Invalid argument: '"${1:-}"$'\nValid: low (l), balanced (b), power (p), auto (a)' 2>/dev/null || true
        echo "Usage: $0 [low|l | balanced|b | power|p | auto|a]" >&2
        exit 1
        ;;
esac
