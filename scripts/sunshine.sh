#!/usr/bin/env fish

function sunshine_toggle
    set action $argv[1]
    set width $SUNSHINE_CLIENT_WIDTH
    set height $SUNSHINE_CLIENT_HEIGHT
    set fps $SUNSHINE_CLIENT_FPS

    # Fallbacks if Sunshine doesn't pass variables correctly
    if test -z "$width"; set width 1920; end
    if test -z "$height"; set height 1080; end
    if test -z "$fps"; set fps 60; end

    switch $action
        case "start"
            # 1. Create the virtual monitor with PC's resolution
            hyprctl output create headless
            
            # 2. Configure the monitor (Positioning it at 0x0)
            # Syntax: monitor = name, res@fps, pos, scale
            hyprctl keyword monitor "HEADLESS-1, {$width}x{$height}@{$fps}, 0x0, 1"
            
            # 3. (Optional) Move your current workspaces to the new monitor
            for i in (hyprctl workspaces -j | jq '.[] | .id')
                hyprctl dispatch moveworkspacetomonitor "$i HEADLESS-1"
            end

        case "stop"
            # 1. Remove the virtual monitor
            hyprctl output remove HEADLESS-1
            
            # 2. Reset the laptop monitor if you disabled it
            hyprctl keyword monitor "eDP-1, preferred, auto, 1"
    end
end

sunshine_toggle $argv
