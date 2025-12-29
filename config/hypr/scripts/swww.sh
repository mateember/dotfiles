#!/usr/bin/env bash

# Set the directory containing the images
IMAGE_DIR="$HOME/Pictures/BingWallpaper"

# Set the transition duration in seconds
TRANSITION_DURATION=10

# Set the interval between image changes in minutes
INTERVAL=7

# Set the frame rate for the transition
FPS=120
pgrep -x swww-daemon > /dev/null || swww-daemon &
# Ensure swww-daemon is running
if ! pgrep -f "swww-daemon" > /dev/null; then
    swww-daemon &
    sleep 1 # Give the daemon a second to initialize
fi

# Get a list of image files in the directory
IMAGES=($(find "$IMAGE_DIR" -type f \( -name "*.jpg" -o -name "*.png" \)))

# Check if there are any images
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "No images found in $IMAGE_DIR"
    exit 1
fi

# --- RANDOM INITIALIZATION ---
# Pick a random starting index
CURRENT_INDEX=$(( RANDOM % ${#IMAGES[@]} ))

# Set the first image immediately without waiting
swww img "${IMAGES[$CURRENT_INDEX]}"

# Loop indefinitely
while true; do
    # Wait for the specified interval
    sleep $((INTERVAL * 60))

    # Calculate a random next image index
    NEXT_INDEX=$(( RANDOM % ${#IMAGES[@]} ))

    # Ensure we don't pick the same image twice in a row
    while [ "$NEXT_INDEX" -eq "$CURRENT_INDEX" ] && [ ${#IMAGES[@]} -gt 1 ]; do
        NEXT_INDEX=$(( RANDOM % ${#IMAGES[@]} ))
    done

    # Set the next image as the wallpaper with a transition
    swww img "${IMAGES[$NEXT_INDEX]}" \
        --transition-step "$TRANSITION_DURATION" \
        --transition-fps "$FPS" \
        --transition-type random

    # Update the current index for the next loop comparison
    CURRENT_INDEX=$NEXT_INDEX
done
