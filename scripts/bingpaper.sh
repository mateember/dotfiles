#!/usr/bin/env bash

# Ensure the directory exists
SAVE_DIR="$HOME/Pictures/BingWallpaper"
mkdir -p "$SAVE_DIR"

# Get current date for the filename
DATE=$(date +%Y-%m-%d)
FILE_PATH="$SAVE_DIR/bing_$DATE.jpg"

# Fetch the 4K image URL from the BitURL API
IMAGE_URL=$(curl -s "https://bing.biturl.top/?resolution=3840&format=json&index=0" | jq -r '.url')

if [ -n "$IMAGE_URL" ] && [ "$IMAGE_URL" != "null" ]; then
    # Download the image
    curl -o "$FILE_PATH" "$IMAGE_URL"
    
    # Optional: Set the wallpaper (Example for GNOME)
    # gsettings set org.gnome.desktop.background picture-uri-lite "file://$FILE_PATH"
    
    echo "Wallpaper saved to $FILE_PATH"
else
    echo "Failed to fetch image URL"
    exit 1
fi
