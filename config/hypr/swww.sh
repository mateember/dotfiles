#!/usr/bin/env bash

# Set the directory containing the images
IMAGE_DIR="$HOME/Pictures/BingWallpaper"

# Set the transition duration in seconds
TRANSITION_DURATION=20

# Set the interval between image changes in minutes
INTERVAL=15

# Set the frame rate for the transition
FPS=120

# Get a list of image files in the directory
IMAGES=($(find "$IMAGE_DIR" -type f \( -name "*.jpg" -o -name "*.png" \)))

# Check if there are any images
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "No images found in $IMAGE_DIR"
    exit 1
fi

# Initialize the current image index
CURRENT_INDEX=0

swww-daemon

# Loop indefinitely
while true; do
    # Set the current image as the wallpaper
    swww img "${IMAGES[$CURRENT_INDEX]}"

    # Wait for the specified interval
    sleep $((INTERVAL * 60))

    # Calculate the next image index
    NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#IMAGES[@]} ))

    # Set the next image as the wallpaper with a transition
    swww img "${IMAGES[$NEXT_INDEX]}" --transition-step  $TRANSITION_DURATION --transition-fps $FPS 
    # Update the current image index
    CURRENT_INDEX=$NEXT_INDEX
done
