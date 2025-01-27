#!/bin/bash

killall .waybar-wrapped
killall .dunst-wrapped
killall .blueman-applet 
killall .nm-applet-wrap

killall waybar
killall dunst
waybar
dunst
waypaper --random
hyprctl reload
