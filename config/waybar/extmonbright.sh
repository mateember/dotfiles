#!/usr/bin/env bash

# PATH to your existing script that sets brightness
# usage of your script should be: ./set_brightness.sh 50
TARGET_SCRIPT="$HOME/.scripts/monbright.sh"

case $1 in
    input)
        # Open a graphical input box asking for a number
        # We verify if the user actually entered a number using a regex
        NEW_VAL=$(zenity --entry --title="Monitor Brightness" --text="Enter brightness (0-100):")
        
        # Check if input is a valid number
        if [[ "$NEW_VAL" =~ ^[0-9]+$ ]]; then
            "$TARGET_SCRIPT" "$NEW_VAL"
        fi
        ;;
    *)
        # Default output for Waybar (Optional: prints an icon)
        echo "" 
        ;;
esac
