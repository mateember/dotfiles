#!/usr/bin/env sh


# 1. Check if a value was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <value>"
    echo "Example: $0 50"
    exit 1
fi

VALUE=$1

# 2. Check if ddccontrol is installed
if ! command -v ddccontrol &> /dev/null; then
    echo "Error: ddccontrol could not be found. Please install it first."
    exit 1
fi

echo "Probing for monitors..."

# 3. Run ddccontrol -p and extract the I2C device
# We search for the pattern '/dev/i2c-[number]' and take the first match.
# 2>/dev/null silences the verbose probing errors that ddccontrol often outputs.
I2C_DEV=$(ddccontrol -p 2>/dev/null | grep -o '/dev/i2c-[0-9]*' | head -n 1)

# 4. Verify we found a device
if [ -z "$I2C_DEV" ]; then
    echo "Error: No I2C monitor device found."
    echo "Make sure the 'i2c-dev' kernel module is loaded (sudo modprobe i2c-dev)."
    exit 1
fi

echo "Found monitor on: $I2C_DEV"
echo "Setting register 0x10 (Brightness) to $VALUE..."

# 5. Run the final command
# Note: ddccontrol often requires root privileges to write to i2c.
ddccontrol -r 0x10 -w "$VALUE" dev:"$I2C_DEV"
