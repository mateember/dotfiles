#!/usr/bin/env bash
# Run by hypridle after waking from suspend (after_sleep_cmd in hypridle.conf).
#
# 1. Turn the display back on (so a key doesn't have to be pressed twice).
# 2. Restart hyprsunset. Its schedule timer doesn't count time spent suspended, so if a
#    profile time (e.g. 8:30, night light off) passes while the laptop sleeps, it never
#    switches and the screen stays warm. A fresh hyprsunset picks the profile from the clock.
# 3. Re-apply a manual Night Light mode (on/off) chosen in the shell, which the restart resets.
set -u

timeout 3 hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null

pkill -x hyprsunset
for _ in $(seq 20); do pgrep -x hyprsunset >/dev/null || break; sleep 0.1; done
# Started through Hyprland so it gets the session environment, like at login.
timeout 3 hyprctl dispatch 'hl.dsp.exec_cmd("hyprsunset")' >/dev/null

# Wait for its IPC to come up, then let the shell re-apply a manual mode.
for _ in $(seq 30); do timeout 1 hyprctl hyprsunset profile >/dev/null 2>&1 && break; sleep 0.2; done
timeout 3 qs ipc call nightlight reapply >/dev/null 2>&1
exit 0
