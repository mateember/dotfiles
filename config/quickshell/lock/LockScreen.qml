import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.services

// Native COSMIC Dark Wayland session lock screen (ext-session-lock-v1 + PAM/Howdy).
// Replaces hyprlock + hyprlock-gen.py + lock.sh:
//   qs ipc call lock lock           — lock immediately and start PAM (Howdy face scan -> password)
//   qs ipc call lock lockForSleep   — lock before suspend WITHOUT starting PAM (prevents Howdy pre-sleep race)
//   qs ipc call lock wakeFromSleep  — start PAM on wake so Howdy scans when opening the laptop
//   qs ipc call lock isLocked       — returns "true" / "false"
Scope {
    id: root

    readonly property bool locked: persist.locked
    readonly property bool sleeping: persist.sleeping
    property bool submittingPassword: false
    property string pendingPassword: ""
    property string errorText: ""
    property bool abortingPam: false

    // Howdy runs first in /etc/pam.d/hyprlock (`auth sufficient pam_howdy.so`) before
    // `pam_unix.so` sets `responseRequired = true`.
    readonly property bool faceScanning: persist.locked && !persist.sleeping
                                         && pam.active && !pam.responseRequired && !root.submittingPassword

    readonly property string rawUser: Quickshell.env("USER") || "User"
    readonly property string displayName: rawUser.charAt(0).toUpperCase() + rawUser.slice(1)
    readonly property string userInitial: displayName.charAt(0).toUpperCase()
    readonly property string greetingText: {
        const h = Time.date.getHours();
        const greet = (h < 5 || h >= 18) ? "Good evening"
                    : (h < 12) ? "Good morning"
                    : "Good afternoon";
        return `${greet}, ${root.displayName}`;
    }

    signal clearInputs()
    signal authFailed()

    PersistentProperties {
        id: persist
        reloadableId: "hcs-lock"
        property bool locked: false
        property bool sleeping: false
    }

    function clearError(): void {
        if (root.errorText !== "") root.errorText = "";
    }

    function notifyUserActivity(): void {
        if (persist.sleeping) root.wakeFromSleep();
        else if (persist.locked && !pam.active && !pamRestartTimer.running && !wakePamTimer.running) root.startPam();
    }

    function dismissShellOverlays(): void {
        Popups.close();
        QuickSettingsState.close();
        if (Hypr.overviewOpen) Hypr.closeOverview();
    }

    function startPam(): void {
        if (!persist.locked || persist.sleeping) return;
        if (pam.active) {
            if (pam.responseRequired && root.pendingPassword !== "") {
                const pw = root.pendingPassword;
                root.pendingPassword = "";
                root.submittingPassword = true;
                pam.respond(pw);
            }
            return;
        }
        root.abortingPam = false;
        pam.start();
    }

    function lock(): void {
        root.dismissShellOverlays();
        wakePamTimer.stop();
        root.errorText = "";
        root.pendingPassword = "";
        root.submittingPassword = false;
        persist.sleeping = false;
        persist.locked = true;
        root.startPam();
    }

    function lockForSleep(): void {
        root.dismissShellOverlays();
        wakePamTimer.stop();
        pamRestartTimer.stop();
        root.errorText = "";
        root.pendingPassword = "";
        root.submittingPassword = false;
        persist.sleeping = true;
        persist.locked = true;
        if (pam.active) {
            root.abortingPam = true;
            pam.abort();
        }
    }

    function wakeFromSleep(): void {
        persist.locked = true;
        persist.sleeping = false;
        root.errorText = "";
        // Give USB/IR camera ~250ms to resume from suspend before Howdy opens /dev/video*.
        if (!pam.active) wakePamTimer.restart();
    }

    function retryFaceScan(): void {
        if (!persist.locked || root.submittingPassword) return;
        persist.sleeping = false;
        root.errorText = "";
        root.pendingPassword = "";
        root.submittingPassword = false;
        wakePamTimer.stop();
        if (pam.active) {
            root.abortingPam = true;
            pam.abort();
            pamRestartTimer.restart();
        } else {
            root.startPam();
        }
    }

    function submitPassword(text: string): void {
        if (!persist.locked || root.submittingPassword) return;
        persist.sleeping = false;
        wakePamTimer.stop();
        root.errorText = "";

        // Empty Enter re-triggers Howdy face unlock cleanly without showing an error.
        if (text.length === 0) {
            root.retryFaceScan();
            return;
        }

        root.submittingPassword = true;
        root.clearInputs();

        if (pam.active && pam.responseRequired) {
            root.pendingPassword = "";
            pam.respond(text);
        } else {
            // Buffer password while Howdy is still scanning (or PAM is starting) so it submits
            // automatically the instant pam_unix sets responseRequired = true.
            root.pendingPassword = text;
            if (!pam.active && !pamRestartTimer.running) {
                root.startPam();
            }
        }
    }

    function unlock(): void {
        wakePamTimer.stop();
        pamRestartTimer.stop();
        if (pam.active) {
            root.abortingPam = true;
            pam.abort();
        }
        root.abortingPam = false;
        root.pendingPassword = "";
        root.submittingPassword = false;
        root.errorText = "";
        root.clearInputs();
        persist.sleeping = false;
        persist.locked = false;

        // Reset hypridle timers on unlock (unless entering sleep) so a hands-free Howdy
        // face unlock doesn't leave the Wayland idle timer counting toward suspend.
        idleResetProc.running = true;
    }

    Timer {
        id: pamRestartTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (pam.active) {
                pamRestartTimer.restart();
                return;
            }
            root.abortingPam = false;
            root.startPam();
        }
    }

    Timer {
        id: wakePamTimer
        interval: 250
        repeat: false
        onTriggered: root.startPam()
    }

    Process {
        id: idleResetProc
        command: [
            "bash", "-c",
            "prep=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager PreparingForSleep 2>/dev/null); " +
            "[ \"$prep\" = \"b true\" ] && exit 0; " +
            "timeout 3 hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' >/dev/null 2>&1; " +
            "pkill -x hypridle; " +
            "for _ in $(seq 20); do pgrep -x hypridle >/dev/null || break; sleep 0.1; done; " +
            "timeout 3 hyprctl dispatch 'hl.dsp.exec_cmd(\"hypridle\")' >/dev/null 2>&1"
        ]
    }

    PamContext {
        id: pam
        config: "hyprlock"
    }

    Connections {
        target: pam

        function onResponseRequiredChanged(): void {
            if (!pam.responseRequired) return;
            if (root.pendingPassword !== "") {
                Qt.callLater(() => {
                    if (pam.active && pam.responseRequired && root.pendingPassword !== "") {
                        const pw = root.pendingPassword;
                        root.pendingPassword = "";
                        root.submittingPassword = true;
                        pam.respond(pw);
                    }
                });
            } else {
                root.submittingPassword = false;
            }
        }

        function onCompleted(result): void {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (root.abortingPam || !persist.locked || persist.sleeping) {
                root.abortingPam = false;
                root.submittingPassword = false;
                return;
            }
            root.submittingPassword = false;
            root.pendingPassword = "";
            if (result === PamResult.MaxTries) {
                root.errorText = "Too many attempts, try again";
            } else if (pam.message && pam.messageIsError) {
                root.errorText = pam.message;
            } else {
                root.errorText = "Wrong password, try again";
            }
            root.authFailed();
            pamRestartTimer.restart();
        }

        function onError(err): void {
            if (root.abortingPam || !persist.locked || persist.sleeping) {
                root.abortingPam = false;
                return;
            }
            root.submittingPassword = false;
            root.pendingPassword = "";
            root.errorText = "Authentication error (" + PamError.toString(err) + ")";
            root.authFailed();
            pamRestartTimer.restart();
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function lockForSleep(): void { root.lockForSleep(); }
        function wakeFromSleep(): void { root.wakeFromSleep(); }
        function isLocked(): bool { return persist.locked; }
    }

    // Ensures PAM restarts after a QML hot-reload if the session was already locked & awake.
    Component.onCompleted: {
        if (persist.locked && !persist.sleeping && !pam.active) {
            Qt.callLater(() => root.startPam());
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: persist.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            LockSurface {
                width: surface.width
                height: surface.height
                controller: root
                screenName: surface.screen?.name ?? ""
            }
        }
    }
}
