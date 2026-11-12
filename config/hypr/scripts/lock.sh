#!/usr/bin/env bash
# Lock screen launcher (Quickshell, ~/.config/quickshell/lock.qml).
#   lock.sh         lock now (password + Howdy face scan)
#   lock.sh sleep   lock before suspend, without starting Howdy
#   lock.sh wake    after resume: start the Howdy scan if the lock screen is running
#
# The lock runs as the transient user unit hcs-lock.service, separate from the bar's process:
#  - the fixed unit name means only one lock instance can exist,
#  - Restart=on-failure restarts it after a crash and it locks again
#    (needs misc:allow_session_lock_restore in Hyprland),
#  - it lives in its own cgroup, so restarting hypridle or the bar never kills it.
set -u
mode="${1:-lock}"
cfg="$HOME/.config/quickshell/lock.qml"
qs_bin="$(command -v qs)" || exit 1

ipc() { timeout 2 "$qs_bin" -p "$cfg" ipc call lock "$@" >/dev/null 2>&1; }

case "$mode" in
    lock) fn=lock ;;
    sleep) fn=lockForSleep ;;
    wake) fn=wakeFromSleep ;;
    *) echo "usage: lock.sh [lock|sleep|wake]" >&2; exit 2 ;;
esac

if systemctl --user is-active --quiet hcs-lock.service; then
    # Already locked: tell the running instance. Retry briefly in case it is still starting.
    for _ in 1 2 3 4 5 6 7 8 9 10; do ipc "$fn" && exit 0; sleep 0.2; done
    exit 0
fi

# Nothing is locked, so there is nothing to wake.
[ "$mode" = wake ] && exit 0

exec systemd-run --user --unit=hcs-lock --collect --quiet \
    -p Restart=on-failure -p RestartSec=0 \
    -E HCS_LOCK_MODE="$mode" \
    "$qs_bin" -p "$cfg"
