#!/usr/bin/env bash

# --- CONFIGURATION ---
IMAGE_DIR="$HOME/Pictures/BingWallpaper"
TRANSITION_STEP=10
INTERVAL=7
FPS=120

# --- DAEMON CHECK ---
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon &
    sleep 1.5 # Increased slightly to ensure socket is ready
fi

# Get image files
IMAGES=($(find "$IMAGE_DIR" -type f \( -name "*.jpg" -o -name "*.png" \)))

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "No images found in $IMAGE_DIR"
    exit 1
fi

get_monitors() {
    hyprctl monitors -j | jq -r '.[] | .name'
}

# --- INITIALIZATION ---
# Small sleep between monitors prevents the "wayland buffer" warning
for MONITOR in $(get_monitors); do
    RANDOM_IMG="${IMAGES[$(( RANDOM % ${#IMAGES[@]} ))]}"
    swww img -o "$MONITOR" "$RANDOM_IMG" --transition-type none > /dev/null 2>&1
    sleep 0.2 
done

# --- MAIN LOOP ---
while true; do
    sleep $((INTERVAL * 60))

    IS_FULLSCREEN=$(hyprctl activewindow -j | jq '.fullscreen' 2>/dev/null)

    for MONITOR in $(get_monitors); do
        NEXT_IMG="${IMAGES[$(( RANDOM % ${#IMAGES[@]} ))]}"
        
        if [ "$IS_FULLSCREEN" != "0" ] && [ "$IS_FULLSCREEN" != "false" ] && [ "$IS_FULLSCREEN" != "null" ]; then
            # GAME MODE
            swww img -o "$MONITOR" "$NEXT_IMG" --transition-type none > /dev/null 2>&1
        else
            # DESKTOP MODE
            swww img -o "$MONITOR" "$NEXT_IMG" \
                --transition-step "$TRANSITION_STEP" \
                --transition-fps "$FPS" \
                --transition-type random > /dev/null 2>&1
        fi
        # Tiny delay to allow the Wayland buffer to catch up
        sleep 0.2
    done
done
