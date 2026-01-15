#!/usr/bin/env sh

# 1. Check if a value was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <value>"
    echo "Example: $0 50"
    exit 1
fi

VALUE=$1

# 2. Check if ddcutil is installed
if ! command -v ddcutil >/dev/null 2>&1; then
    echo "Error: ddcutil could not be found. Please install it first."
    echo "Try: sudo apt install ddcutil"
    exit 1
fi

echo "Probing for monitors..."

# 3. Detect the monitor and get the first display number
# ddcutil detect is more reliable than manual grep on /dev/i2c-*
DISPLAY_NUM=$(ddcutil detect --brief | grep "Display" | head -n 1 | awk '{print $2}')

# 4. Verify we found a device
if [ -z "$DISPLAY_NUM" ]; then
    echo "Error: No DDC/CI capable monitor found."
    echo "Check if the 'i2c-dev' kernel module is loaded: sudo modprobe i2c-dev"
    echo "Also check permissions: Is your user in the 'i2c' group?"
    exit 1
fi

echo "Found monitor as Display $DISPLAY_NUM"
echo "Setting VCP feature 0x10 (Brightness) to $VALUE..."

# 5. Run the final command
# --display identifies the monitor index found during detection
# --sleep-multiplier can be added if your monitor is slow to respond (e.g., .5)
ddcutil setvcp 10 "$VALUE" --display "$DISPLAY_NUM"
