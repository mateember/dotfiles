#!/usr/bin/env bash

# Check if playerctl is installed
if ! command -v playerctl &> /dev/null; then
    echo "playerctl is not installed. Please install it and try again."
    exit 1
fi

# Get the currently playing player
ACTIVE_PLAYER=$(playerctl -l 2>/dev/null | grep -v '^playerctld$' | head -n 1)

if [ -z "$ACTIVE_PLAYER" ]; then
    echo "No media is currently playing."
    exit 0
fi

# Get the title and artist of the currently playing media
TITLE=$(playerctl -p "$ACTIVE_PLAYER" metadata title 2>/dev/null)
ARTIST=$(playerctl -p "$ACTIVE_PLAYER" metadata artist 2>/dev/null)

# Check if metadata is available
if [ -z "$TITLE" ]; then
    echo "No media is currently playing on $ACTIVE_PLAYER."
else
    echo "Now Playing: $TITLE - $ARTIST"
fi

