import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.services

// Native COSMIC Dark Wayland session lock screen (ext-session-lock-v1 + dual PAM).
// Runs in its own Quickshell instance (../lock.qml, started by ~/.config/hypr/scripts/lock.sh)
// and exits after unlocking.
// Runs two independent PAM conversations in parallel:
//   1. `passwordPam` (/etc/pam.d/qs-lock, pure pam_unix): ready at 0ms so typing and
//      pressing Enter unlocks IMMEDIATELY even while Howdy is still scanning.
//   2. `facePam` (/etc/pam.d/qs-lock-face, pam_howdy): runs Howdy IR face recognition when Howdy
//      is installed, enabled, camera is present, and $USER has >= 1 enrolled face model.
// Both PAM services are defined in ~/Nix/hosts/matevono/desktop.nix (security.pam.services).
//
// IPC (`qs -p ~/.config/quickshell/lock.qml ipc call lock ...`, normally via lock.sh):
//   lock           — lock immediately and start passwordPam + facePam (if howdyAvailable)
//   lockForSleep   — lock before suspend WITHOUT starting facePam (prevents Howdy pre-sleep race)
//   wakeFromSleep  — start facePam on wake so Howdy scans when opening the laptop
//   isLocked       — returns "true" / "false"
Scope {
    id: root

    readonly property bool locked: persist.locked
    readonly property bool sleeping: persist.sleeping
    property bool howdyAvailable: false
    property string facePamConfig: "qs-lock-face"
    property string passwordPamConfig: "qs-lock"
    property bool probeDone: false

    // Per-screen wallpaper URLs from the bar instance, so the lock shows the desktop's image.
    property var wallpaperMap: ({})
    property string wallpaperCurrent: ""
    property bool wallpaperReady: false

    function wallpaperFor(screenName: string): string {
        if (screenName && root.wallpaperMap[screenName]) return root.wallpaperMap[screenName];
        return root.wallpaperCurrent;
    }

    property bool submittingPassword: false
    property string pendingPassword: ""
    property string errorText: ""
    property bool abortingFacePam: false
    property bool abortingPasswordPam: false

    readonly property bool faceScanning: persist.locked && !persist.sleeping && root.howdyAvailable
                                         && facePam.active && !facePam.responseRequired

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
        if (!persist.locked) return;
        if (persist.sleeping) {
            root.wakeFromSleep();
            return;
        }
        if (!passwordPam.active && !passwordPamRestartTimer.running) {
            root.startPasswordPam();
        }
    }

    // The bar's popups live in the other Quickshell instance (shell.qml); close them over IPC.
    function dismissShellOverlays(): void {
        if (!overlayCloseProc.running) overlayCloseProc.running = true;
    }

    function startPasswordPam(): bool {
        if (!persist.locked) return false;
        if (passwordPam.active) {
            if (passwordPam.responseRequired && root.pendingPassword !== "") {
                const pw = root.pendingPassword;
                root.pendingPassword = "";
                root.submittingPassword = true;
                submitWatchdog.restart();
                passwordPam.respond(pw);
            }
            return true;
        }
        if (passwordPam.config !== root.passwordPamConfig) passwordPam.config = root.passwordPamConfig;
        root.abortingPasswordPam = false;
        const ok = passwordPam.start();
        if (ok && root.errorText.startsWith("Failed to start PAM")) root.errorText = "";
        if (!ok) {
            submitWatchdog.stop();
            root.submittingPassword = false;
            root.pendingPassword = "";
            root.errorText = "Failed to start PAM (/etc/pam.d/" + root.passwordPamConfig + ")";
        }
        return ok;
    }

    function startFacePam(): void {
        if (!persist.locked || persist.sleeping || !root.howdyAvailable || !root.facePamConfig) return;
        if (facePam.active) return;
        if (facePam.config !== root.facePamConfig) facePam.config = root.facePamConfig;
        root.abortingFacePam = false;
        facePam.start();
    }

    function stopFacePam(): void {
        wakeFaceTimer.stop();
        facePamRestartTimer.stop();
        if (facePam.active) {
            root.abortingFacePam = true;
            facePam.abort();
        }
    }

    function stopAllPam(): void {
        root.stopFacePam();
        passwordPamRestartTimer.stop();
        if (passwordPam.active) {
            root.abortingPasswordPam = true;
            passwordPam.abort();
        }
    }

    function refreshPamProbe(): void {
        if (!pamProbeProc.running) pamProbeProc.running = true;
    }

    function lock(): void {
        root.dismissShellOverlays();
        wakeFaceTimer.stop();
        root.errorText = "";
        root.pendingPassword = "";
        root.submittingPassword = false;
        persist.sleeping = false;
        persist.locked = true;
        root.refreshPamProbe();
        root.startPasswordPam();
        if (root.howdyAvailable) root.startFacePam();
    }

    function lockForSleep(): void {
        root.dismissShellOverlays();
        root.stopFacePam();
        root.errorText = "";
        root.pendingPassword = "";
        root.submittingPassword = false;
        persist.sleeping = true;
        persist.locked = true;
        root.refreshPamProbe();
        // Keep passwordPam ready (touches zero hardware/camera) while facePam stays off before sleep.
        root.startPasswordPam();
    }

    function suspendSystem(): void {
        root.lockForSleep();
        Media.pause();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function wakeFromSleep(): void {
        persist.locked = true;
        persist.sleeping = false;
        root.errorText = "";
        root.refreshPamProbe();
        root.startPasswordPam();
        // Give USB/IR camera ~250ms to resume from suspend before Howdy opens /dev/video*.
        if (root.howdyAvailable && !facePam.active) wakeFaceTimer.restart();
    }

    function retryFaceScan(): void {
        if (!persist.locked || root.submittingPassword || !root.howdyAvailable) return;
        persist.sleeping = false;
        root.errorText = "";
        wakeFaceTimer.stop();
        if (!passwordPam.active && !passwordPamRestartTimer.running) root.startPasswordPam();
        if (facePam.active) {
            root.abortingFacePam = true;
            facePam.abort();
            facePamRestartTimer.restart();
        } else {
            root.startFacePam();
        }
    }

    function cancelSubmit(): void {
        if (!root.submittingPassword) return;
        submitWatchdog.stop();
        root.submittingPassword = false;
        root.pendingPassword = "";
        root.errorText = "";
        if (passwordPam.active) {
            root.abortingPasswordPam = true;
            passwordPam.abort();
        }
        passwordPamRestartTimer.restart();
    }

    function submitPassword(text: string): void {
        if (!persist.locked || root.submittingPassword) return;
        persist.sleeping = false;
        root.errorText = "";

        // Empty Enter re-triggers Howdy face unlock when Howdy is available; no-op otherwise.
        if (text.length === 0) {
            if (root.howdyAvailable) root.retryFaceScan();
            return;
        }

        root.submittingPassword = true;
        submitWatchdog.restart();
        root.clearInputs();

        // passwordPam has no pam_howdy, so it verifies immediately even while facePam is scanning!
        if (passwordPam.active && passwordPam.responseRequired) {
            root.pendingPassword = "";
            passwordPam.respond(text);
        } else {
            root.pendingPassword = text;
            if (!passwordPam.active && !passwordPamRestartTimer.running) {
                root.startPasswordPam();
            }
        }
    }

    function unlock(): void {
        submitWatchdog.stop();
        root.stopAllPam();
        root.abortingFacePam = false;
        root.abortingPasswordPam = false;
        root.pendingPassword = "";
        root.submittingPassword = false;
        root.errorText = "";
        root.clearInputs();
        persist.sleeping = false;
        persist.locked = false;

        // Reset hypridle timers on unlock (unless entering sleep) so a hands-free Howdy
        // face unlock doesn't leave the Wayland idle timer counting toward suspend.
        // This instance exits once that is done (or after quitTimer if it hangs).
        idleResetProc.running = true;
        quitTimer.restart();
    }

    // Exit after unlock. Exit code 0, so systemd (Restart=on-failure) doesn't start it again.
    function quitIfUnlocked(): void {
        if (!persist.locked) Qt.quit();
    }

    Timer {
        id: quitTimer
        interval: 15000
        repeat: false
        onTriggered: root.quitIfUnlocked()
    }

    Timer {
        id: passwordPamRestartTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (passwordPam.active) {
                passwordPamRestartTimer.restart();
                return;
            }
            root.abortingPasswordPam = false;
            root.startPasswordPam();
        }
    }

    Timer {
        id: facePamRestartTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (facePam.active) {
                facePamRestartTimer.restart();
                return;
            }
            root.abortingFacePam = false;
            root.startFacePam();
        }
    }

    Timer {
        id: wakeFaceTimer
        interval: 250
        repeat: false
        onTriggered: root.startFacePam()
    }

    // Safety watchdog so password submission can never leave the input stuck in "Unlocking…"
    Timer {
        id: submitWatchdog
        interval: 6000
        repeat: false
        onTriggered: {
            if (!root.submittingPassword) return;
            root.submittingPassword = false;
            root.pendingPassword = "";
            root.errorText = "Authentication timed out, try again";
            if (passwordPam.active) {
                root.abortingPasswordPam = true;
                passwordPam.abort();
            }
            passwordPamRestartTimer.restart();
        }
    }

    // Probes Howdy availability (PAM service has pam_howdy + Howdy enabled + camera exists +
    // user has >=1 face model). PAM service files come from /etc/pam.d only (root-owned, from Nix).
    Process {
        id: pamProbeProc
        command: [
            "sh", "-c",
            "user=\"${USER:-$(id -un)}\"; " +
            "pw_cfg=qs-lock; " +
            "face_cfg=\"\"; grep -q pam_howdy /etc/pam.d/qs-lock-face 2>/dev/null && face_cfg=qs-lock-face; " +
            "howdy_ok=0; " +
            "if [ -n \"$face_cfg\" ]; then " +
            "  disabled=0; dev_ok=1; " +
            "  if [ -f /etc/howdy/config.ini ]; then " +
            "    grep -Eq '^[[:space:]]*disabled[[:space:]]*=[[:space:]]*true' /etc/howdy/config.ini && disabled=1; " +
            "    dev=$(sed -n 's/^[[:space:]]*device_path[[:space:]]*=[[:space:]]*//p' /etc/howdy/config.ini | head -n1 | tr -d '[:space:]'); " +
            "    [ -n \"$dev\" ] && [ \"$dev\" != \"none\" ] && [ ! -e \"$dev\" ] && dev_ok=0; " +
            "  fi; " +
            "  models_ok=0; unreadable_dir=0; " +
            "  for d in /var/lib/howdy/models /etc/howdy/models /lib/security/howdy/models /usr/lib/security/howdy/models; do " +
            "    if [ -d \"$d\" ]; then " +
            "      if [ -r \"$d\" ]; then " +
            "        [ -s \"$d/$user.dat\" ] && grep -q '\"data\"' \"$d/$user.dat\" 2>/dev/null && models_ok=1 && break; " +
            "      else unreadable_dir=1; fi; " +
            "    fi; " +
            "  done; " +
            "  [ \"$models_ok\" -eq 0 ] && [ \"$unreadable_dir\" -eq 1 ] && models_ok=1; " +
            "  [ \"$disabled\" -eq 0 ] && [ \"$dev_ok\" -eq 1 ] && [ \"$models_ok\" -eq 1 ] && howdy_ok=1; " +
            "fi; " +
            "printf '{\"howdyAvailable\":%s,\"faceConfig\":\"%s\",\"passwordConfig\":\"%s\"}\\n' " +
            "  \"$([ \"$howdy_ok\" -eq 1 ] && echo true || echo false)\" \"$face_cfg\" \"$pw_cfg\""
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const info = JSON.parse(line.trim());
                    root.howdyAvailable = Boolean(info.howdyAvailable);
                    if (info.faceConfig) root.facePamConfig = String(info.faceConfig);
                    if (info.passwordConfig) root.passwordPamConfig = String(info.passwordConfig);
                    root.probeDone = true;

                    if (persist.locked) {
                        if (!passwordPam.active && !passwordPamRestartTimer.running) root.startPasswordPam();
                        if (root.howdyAvailable && !persist.sleeping && !facePam.active && !wakeFaceTimer.running) {
                            root.startFacePam();
                        } else if (!root.howdyAvailable && facePam.active) {
                            root.stopFacePam();
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: idleResetProc
        command: [
            "bash", "-c",
            "prep=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager PreparingForSleep 2>/dev/null); " +
            "[ \"$prep\" = \"b true\" ] && exit 0; " +
            "timeout 3 hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' >/dev/null 2>&1; " +
            "~/.config/hypr/scripts/reassert-cursor.sh >/dev/null 2>&1; " +
            // A fresh hypridle registers new idle timers. systemd guarantees it comes back up;
            // the lock instance is in its own unit (hcs-lock.service), so this can't kill it.
            "timeout 5 systemctl --user restart hypridle.service"
        ]
        onExited: root.quitIfUnlocked()
    }

    // Close bar popups, Quick Settings and the overview in the bar instance (default qs config).
    Process {
        id: overlayCloseProc
        command: [
            "sh", "-c",
            "for t in bar quicksettings overview; do timeout 2 qs ipc call \"$t\" close >/dev/null 2>&1; done"
        ]
    }

    // Ask the bar instance which wallpaper each screen shows (Wallpapers.qml `screenUrls`).
    // If the bar isn't running, LockSurface falls back to a random image from the folder.
    Process {
        id: wallpaperProc
        command: ["timeout", "2", "qs", "ipc", "call", "wallpaper", "screenUrls"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(this.text.trim());
                    root.wallpaperMap = info.screens ?? {};
                    root.wallpaperCurrent = String(info.current ?? "");
                } catch (e) {}
            }
        }
        onExited: root.wallpaperReady = true
    }

    // Pure password PAM conversation (instant prompt, zero Howdy wait).
    PamContext {
        id: passwordPam
        config: "qs-lock"
    }

    Connections {
        target: passwordPam

        function onResponseRequiredChanged(): void {
            if (!passwordPam.responseRequired) return;
            if (root.pendingPassword !== "") {
                Qt.callLater(() => {
                    if (passwordPam.active && passwordPam.responseRequired && root.pendingPassword !== "") {
                        const pw = root.pendingPassword;
                        root.pendingPassword = "";
                        root.submittingPassword = true;
                        passwordPam.respond(pw);
                    }
                });
            }
        }

        function onCompleted(result): void {
            submitWatchdog.stop();
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (root.abortingPasswordPam || !persist.locked) {
                root.abortingPasswordPam = false;
                root.submittingPassword = false;
                return;
            }
            root.submittingPassword = false;
            root.pendingPassword = "";
            if (result === PamResult.MaxTries) {
                root.errorText = "Too many attempts, try again";
            } else if (passwordPam.message && passwordPam.messageIsError) {
                root.errorText = passwordPam.message;
            } else {
                root.errorText = "Wrong password, try again";
            }
            root.authFailed();
            passwordPamRestartTimer.restart();
        }

        function onError(err): void {
            submitWatchdog.stop();
            if (root.abortingPasswordPam || !persist.locked) {
                root.abortingPasswordPam = false;
                return;
            }
            root.submittingPassword = false;
            root.pendingPassword = "";
            root.errorText = "Authentication error (" + PamError.toString(err) + ")";
            root.authFailed();
            passwordPamRestartTimer.restart();
        }
    }

    // Parallel biometric (Howdy) PAM conversation.
    PamContext {
        id: facePam
        config: "qs-lock-face"
    }

    Connections {
        target: facePam

        function onResponseRequiredChanged(): void {
            // Once /etc/pam.d/qs-lock-face falls through from pam_howdy.so to pam_unix.so,
            // Howdy has finished scanning without a match; abort facePam cleanly since
            // passwordPam is already handling password entry in parallel.
            if (facePam.responseRequired) {
                root.abortingFacePam = true;
                facePam.abort();
            }
        }

        function onCompleted(result): void {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.abortingFacePam = false;
        }

        function onError(): void {
            root.abortingFacePam = false;
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function lockForSleep(): void { root.lockForSleep(); }
        function wakeFromSleep(): void { root.wakeFromSleep(); }
        function isLocked(): bool { return persist.locked; }
        function status(): string {
            return JSON.stringify({
                locked: persist.locked,
                sleeping: persist.sleeping,
                howdyAvailable: root.howdyAvailable,
                faceConfig: root.facePamConfig,
                passwordConfig: root.passwordPamConfig,
                passwordPamActive: passwordPam.active,
                passwordPromptReady: passwordPam.responseRequired,
                facePamActive: facePam.active
            });
        }
    }

    Component.onCompleted: {
        root.refreshPamProbe();
        wallpaperProc.running = true;
        if (persist.locked) {
            // Hot reload while locked: keep the lock, restart the PAM conversations.
            Qt.callLater(() => {
                root.startPasswordPam();
                if (!persist.sleeping && root.howdyAvailable) root.startFacePam();
            });
        } else if (Quickshell.env("HCS_LOCK_MODE") === "sleep") {
            root.lockForSleep();
        } else {
            root.lock();
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
