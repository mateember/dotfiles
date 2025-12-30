#!/usr/bin/env bash

# --- CONFIGURATION ---
IMAGE_DIR="$HOME/Pictures/BingWallpaper"
mkdir -p "$IMAGE_DIR"

# Unsplash API Key (Free at https://unsplash.com/developers)
UNSPLASH_KEY="J3j2sED2fuPoHMf-QElfv6-khLGkF5QcOcvAJCMj7r4"

DATE=$(date +%Y-%m-%d)

# --- BING 4K DOWNLOAD ---
BING_FILE="$IMAGE_DIR/bing_$DATE.jpg"
if [ ! -f "$BING_FILE" ]; then
    echo "Fetching Bing 4K for $DATE..."
    # resolution=3840 targets 4K UHD
    BING_URL=$(curl -s "https://bing.biturl.top/?resolution=3840&format=json&index=0" | jq -r '.url')
    
    if [ -n "$BING_URL" ] && [ "$BING_URL" != "null" ]; then
        curl -Lo "$BING_FILE" "$BING_URL"
    fi
fi

# --- UNSPLASH 4K DOWNLOAD ---
if [ "$UNSPLASH_KEY" != "YOUR_ACCESS_KEY_HERE" ]; then
    UNSPLASH_FILE="$IMAGE_DIR/unsplash_$DATE.jpg"
    if [ ! -f "$UNSPLASH_FILE" ]; then
        echo "Fetching Unsplash 4K for $DATE..."
        # Requesting 'raw' URL to apply custom 4K transformation parameters
        UNSPLASH_URL=$(curl -s "https://api.unsplash.com/photos/random?orientation=landscape&client_id=$UNSPLASH_KEY" | jq -r '.urls.raw')
        
        if [ -n "$UNSPLASH_URL" ] && [ "$UNSPLASH_URL" != "null" ]; then
            # &w=3840&h=2160&fit=crop ensures exactly 4K resolution
            curl -Lo "$UNSPLASH_FILE" "${UNSPLASH_URL}&w=3840&h=2160&fit=crop&q=85"
        fi
    fi
else
    echo "Skipping Unsplash: No API Key provided."
fi
