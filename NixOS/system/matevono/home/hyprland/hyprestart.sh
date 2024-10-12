#!/bin/bash

killall .waybar-wrapped
killall .dunst-wrapped

killall waybar
killall dunst
waybar
dunst
hyprctl reload
