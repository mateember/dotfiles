#!/usr/bin/env bash

# Nerd Font icons (customize as needed)
ICON_WIFI=""       # Wi-Fi icon
ICON_ETHERNET=""   # Ethernet icon
ICON_DISCONNECTED="" # Disconnected icon

# Check the network connection status using nmcli
ACTIVE_CONNECTION=$(nmcli -t -f TYPE,STATE connection show --active | grep ":activated" | awk -F: '{print $1}')
if [[ -z "$ACTIVE_CONNECTION" ]]; then
    # No active connection
    echo "$ICON_DISCONNECTED  Disconnected"
elif [[ "$ACTIVE_CONNECTION" =~ (wifi|wireless) ]]; then
    # Connected via Wi-Fi
    echo "$ICON_WIFI  Connected (Wi-Fi)"
elif [[ "$ACTIVE_CONNECTION" =~ (ethernet|wired) ]]; then
    # Connected via Ethernet
    echo "$ICON_ETHERNET  Connected (Ethernet)"
else
    # Unknown connection type
    echo "$ICON_DISCONNECTED  Unknown connection type"
fi
