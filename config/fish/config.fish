

#set -x QT_AUTO_SCREEN_SCALE_FACTOR 2

set fish_greeting

starship init fish | source
zoxide init fish | source

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/mate/.lmstudio/bin
# End of LM Studio CLI section


