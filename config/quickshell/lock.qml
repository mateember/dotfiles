// Lock screen entry point. Runs as its own Quickshell instance, separate from the bar
// (shell.qml), so a crash or restart of the bar can't leave an active lock without a client.
//
// Started by ~/.config/hypr/scripts/lock.sh as the transient systemd user unit hcs-lock.service.
// Restart=on-failure brings it back after a crash and it re-locks (Hyprland allows that with
// misc:allow_session_lock_restore). It exits after a successful unlock.
//
// HCS_LOCK_MODE=sleep starts it without the Howdy face scan (used right before suspend).
import QtQuick
import Quickshell
import qs.lock

ShellRoot {
    LockScreen {}
}
