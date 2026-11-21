#!/usr/bin/env bash
set -euo pipefail

IMAGE_DIR="$HOME/Pictures/BingWallpaper"
mkdir -p "$IMAGE_DIR"

DATE=$(date +%Y-%m-%d)
BING_FILE="$IMAGE_DIR/bing_$DATE.jpg"

if [ ! -s "$BING_FILE" ]; then
    echo "Fetching Bing 4K for $DATE..."
    BING_URL=$(curl -fsS --max-time 15 --proto '=https' "https://bing.biturl.top/?resolution=3840&format=json&index=0" | jq -r '.url // empty')

    if [[ "$BING_URL" =~ ^https://([a-z0-9-]+\.)?bing\.com/ ]]; then
        tmp=$(mktemp -p "$IMAGE_DIR" ".bing_${DATE}.XXXXXX.tmp")
        trap 'rm -f "$tmp"' EXIT
        curl -fsSL --max-time 30 --proto '=https' --proto-redir '=https' -o "$tmp" -- "$BING_URL"
        if [ -s "$tmp" ]; then
            mv -f "$tmp" "$BING_FILE"
            trap - EXIT
        else
            echo "bingpaper: downloaded file was empty" >&2
            exit 1
        fi
    else
        echo "bingpaper: rejected unexpected Bing image URL" >&2
        exit 1
    fi
fi
