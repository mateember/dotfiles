#!/usr/bin/env bash

# --- CONFIGURATION ---
IMAGE_DIR="$HOME/Pictures/BingWallpaper"
TRANSITION_STEP=10
INTERVAL=7
FPS=120

# --- DAEMON CHECK ---
# Using pgrep to check for your specific daemon
if ! pgrep -x "awww-daemon" >/dev/null; then
  awww-daemon &
  sleep 1.5
fi

# Get image files
IMAGES=($(find "$IMAGE_DIR" -type f \( -name "*.jpg" -o -name "*.png" \)))

if [ ${#IMAGES[@]} -eq 0 ]; then
  echo "No images found in $IMAGE_DIR"
  exit 1
fi

# --- NIRI SPECIFIC FUNCTIONS ---

# Fetches monitor names from Niri's JSON output
get_monitors() {
  niri msg -j outputs | jq -r 'keys[]'
}

# Checks if the currently focused window is fullscreen
is_fullscreen() {
  # Niri returns a list of windows; we find the focused one and check its fullscreen status
  niri msg -j windows | jq -r '.[] | select(.is_focused == true) | .is_fullscreen'
}

# --- INITIALIZATION ---
for MONITOR in $(get_monitors); do
  RANDOM_IMG="${IMAGES[$((RANDOM % ${#IMAGES[@]}))]}"
  awww img -o "$MONITOR" "$RANDOM_IMG" --transition-type none >/dev/null 2>&1
  sleep 0.2
done

# --- MAIN LOOP ---
while true; do
  sleep $((INTERVAL * 60))

  # Get fullscreen status for the focused window
  FS_STATUS=$(is_fullscreen)

  for MONITOR in $(get_monitors); do
    NEXT_IMG="${IMAGES[$((RANDOM % ${#IMAGES[@]}))]}"

    # Niri returns 'true' or 'false' as a boolean in JSON
    if [ "$FS_STATUS" = "true" ]; then
      # GAME MODE (No transition to save resources/prevent flicker)
      awww img -o "$MONITOR" "$NEXT_IMG" --transition-type none >/dev/null 2>&1
    else
      # DESKTOP MODE
      awww img -o "$MONITOR" "$NEXT_IMG" \
        --transition-step "$TRANSITION_STEP" \
        --transition-fps "$FPS" \
        --transition-type random >/dev/null 2>&1
    fi

    sleep 0.2
  done
done
