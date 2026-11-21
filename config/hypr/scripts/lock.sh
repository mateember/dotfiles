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

ipc() { timeout 0.5 "$qs_bin" -p "$cfg" ipc call lock "$@" >/dev/null 2>&1; }
unit_state() { systemctl --user show -p ActiveState --value hcs-lock.service 2>/dev/null || echo "inactive"; }

case "$mode" in
    lock) fn=lock ;;
    sleep) fn=lockForSleep ;;
    wake) fn=wakeFromSleep ;;
    *) echo "usage: lock.sh [lock|sleep|wake]" >&2; exit 2 ;;
esac

state="$(unit_state)"
if [ "$state" = "active" ] || [ "$state" = "activating" ]; then
    # Already running or starting: tell the running instance. Keep total wait under
    # systemd's InhibitDelayMaxSec (5s) and re-check state in case it exited during unlock teardown.
    for _ in 1 2 3 4 5 6; do
        ipc "$fn" && exit 0
        state="$(unit_state)"
        [ "$state" = "inactive" ] || [ "$state" = "failed" ] || [ "$state" = "deactivating" ] && break
        sleep 0.15
    done
    # If still active and unresponsive on wake, nothing more to do; on lock/sleep, restart cleanly.
    if [ "$state" = "active" ]; then
        [ "$mode" = wake ] && exit 0
        systemctl --user stop hcs-lock.service >/dev/null 2>&1 || true
        state="$(unit_state)"
    fi
fi

# Nothing is locked, so there is nothing to wake.
[ "$mode" = wake ] && exit 0

# Wait briefly if the previous unit is still tearing down after unlock so systemd-run
# does not collide with an existing transient unit name.
if [ "$state" = "deactivating" ]; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        state="$(unit_state)"
        [ "$state" != "deactivating" ] && break
        sleep 0.1
    done
fi
[ "$state" = "failed" ] && systemctl --user reset-failed hcs-lock.service >/dev/null 2>&1 || true

exec systemd-run --user --unit=hcs-lock --collect --quiet \
    -p Restart=on-failure -p RestartSec=0.2 -p StartLimitIntervalSec=0 \
    -E HCS_LOCK_MODE="$mode" \
    "$qs_bin" -p "$cfg"
