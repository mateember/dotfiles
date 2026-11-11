#!/usr/bin/env bash
# hypridle's lock_cmd (also what `loginctl lock-session` ends up running).
#
# Howdy (face unlock, first in hyprlock's PAM stack) can unlock without any keyboard/mouse
# input, so hypridle keeps counting the session as idle and would suspend a few minutes
# after a face unlock while you're sitting in front of it. Restarting hypridle after an
# unlock resets its idle timers.
set -u

pidof hyprlock >/dev/null && exit 0
hyprlock

# Don't touch hypridle while the system is going to sleep: it has to stay up to run
# after_sleep_cmd (which locks again on wake, see after-sleep.sh).
preparing=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager PreparingForSleep 2>/dev/null)
[ "$preparing" = "b true" ] && exit 0

pkill -x hypridle
for _ in $(seq 20); do pgrep -x hypridle >/dev/null || break; sleep 0.1; done
timeout 3 hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")' >/dev/null
exit 0
