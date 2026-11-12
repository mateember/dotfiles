#!/usr/bin/env bash

IMAGE_DIR="$HOME/Pictures/BingWallpaper"
mkdir -p "$IMAGE_DIR"

DATE=$(date +%Y-%m-%d)

BING_FILE="$IMAGE_DIR/bing_$DATE.jpg"
if [ ! -f "$BING_FILE" ]; then
  echo "Fetching Bing 4K for $DATE..."
  BING_URL=$(curl -s "https://bing.biturl.top/?resolution=3840&format=json&index=0" | jq -r '.url')

  if [ -n "$BING_URL" ] && [ "$BING_URL" != "null" ]; then
    curl -Lo "$BING_FILE" "$BING_URL"
  fi
fi
