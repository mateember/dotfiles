if status is-interactive
    # Commands to run in interactive sessions can go here
end

set fish_greeting

#set -x QT_AUTO_SCREEN_SCALE_FACTOR 2

starship init fish | source
zoxide init fish | source
