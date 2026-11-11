import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.services

// Native COSMIC Dark Wayland session lock screen (ext-session-lock-v1 + dual PAM).
// Runs two independent PAM conversations in parallel:
//   1. `passwordPam` (pure pam_unix, e.g. /etc/pam.d/vlock): ready at 0ms so typing and
//      pressing Enter unlocks IMMEDIATELY even while Howdy is still scanning.
//   2. `facePam` (/etc/pam.d/hyprlock): runs Howdy IR face recognition when Howdy is
//      installed, enabled, camera is present, and $USER has >= 1 enrolled face model.
//
// IPC (`qs ipc call lock ...`):
//   lock           — lock immediately and start passwordPam + facePam (if howdyAvailable)
//   lockForSleep   — lock before suspend WITHOUT starting facePam (prevents Howdy pre-sleep race)
//   wakeFromSleep  — start facePam on wake so Howdy scans when opening the laptop
//   isLocked       — returns "true" / "false"
Scope {
    id: root

    readonly property bool locked: persist.locked
    readonly property bool sleeping: persist.sleeping
    property bool howdyAvailable: false
    property string facePamConfig: "hyprlock"
    property string passwordPamConfig: "vlock"
    property string passwordPamDir: "/etc/pam.d"
    property bool probeDone: false

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

    function dismissShellOverlays(): void {
        Popups.close();
        QuickSettingsState.close();
        if (Hypr.overviewOpen) Hypr.closeOverview();
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
        const targetDir = root.passwordPamDir || "/etc/pam.d";
        if (passwordPam.config !== root.passwordPamConfig) passwordPam.config = root.passwordPamConfig;
        if (passwordPam.configDirectory !== targetDir) passwordPam.configDirectory = targetDir;
        root.abortingPasswordPam = false;
        const ok = passwordPam.start();
        if (!ok) {
            submitWatchdog.stop();
            root.submittingPassword = false;
            root.pendingPassword = "";
            root.errorText = "Failed to start PAM (" + targetDir + "/" + root.passwordPamConfig + ")";
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
        idleResetProc.running = true;
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

    // Probes PAM configs & Howdy availability (installed + enabled + camera exists + user has >=1 face model).
    Process {
        id: pamProbeProc
        command: [
            "sh", "-c",
            "user=\"${USER:-$(id -un)}\"; " +
            "face_cfg=\"\"; " +
            "for c in hyprlock swaylock login su; do " +
            "  if [ -f \"/etc/pam.d/$c\" ] && grep -q \"pam_howdy\" \"/etc/pam.d/$c\" 2>/dev/null; then face_cfg=\"$c\"; break; fi; " +
            "done; " +
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
            "pw_dir=\"/etc/pam.d\"; pw_cfg=\"\"; " +
            "for c in vlock xlock hyprlock swaylock login; do " +
            "  if [ -f \"/etc/pam.d/$c\" ] && ! grep -q \"pam_howdy\" \"/etc/pam.d/$c\" 2>/dev/null; then pw_cfg=\"$c\"; break; fi; " +
            "done; " +
            "if [ -z \"$pw_cfg\" ]; then " +
            "  pw_dir=\"${XDG_RUNTIME_DIR:-/tmp}/hcs-pam\"; mkdir -p -m 700 \"$pw_dir\"; " +
            "  src=\"/etc/pam.d/${face_cfg:-login}\"; " +
            "  if [ -f \"$src\" ]; then grep -v \"pam_howdy\" \"$src\" > \"$pw_dir/password\"; chmod 600 \"$pw_dir/password\"; pw_cfg=\"password\"; " +
            "  else pw_dir=\"/etc/pam.d\"; pw_cfg=\"login\"; fi; " +
            "fi; " +
            "printf '{\"howdyAvailable\":%s,\"faceConfig\":\"%s\",\"passwordConfig\":\"%s\",\"passwordDir\":\"%s\"}\\n' " +
            "  \"$([ \"$howdy_ok\" -eq 1 ] && echo true || echo false)\" \"$face_cfg\" \"$pw_cfg\" \"$pw_dir\""
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const info = JSON.parse(line.trim());
                    root.howdyAvailable = Boolean(info.howdyAvailable);
                    if (info.faceConfig) root.facePamConfig = String(info.faceConfig);
                    if (info.passwordConfig) root.passwordPamConfig = String(info.passwordConfig);
                    root.passwordPamDir = String(info.passwordDir || "/etc/pam.d");
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
            "pkill -x hypridle; " +
            "for _ in $(seq 20); do pgrep -x hypridle >/dev/null || break; sleep 0.1; done; " +
            "timeout 3 hyprctl dispatch 'hl.dsp.exec_cmd(\"hypridle\")' >/dev/null 2>&1"
        ]
    }

    // Pure password PAM conversation (instant prompt, zero Howdy wait).
    PamContext {
        id: passwordPam
        config: "vlock"
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
        config: "hyprlock"
    }

    Connections {
        target: facePam

        function onResponseRequiredChanged(): void {
            // Once /etc/pam.d/hyprlock falls through from pam_howdy.so to pam_unix.so,
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
                passwordDir: root.passwordPamDir,
                passwordPamActive: passwordPam.active,
                passwordPromptReady: passwordPam.responseRequired,
                facePamActive: facePam.active
            });
        }
    }

    Component.onCompleted: {
        root.refreshPamProbe();
        if (persist.locked) {
            Qt.callLater(() => {
                root.startPasswordPam();
                if (!persist.sleeping && root.howdyAvailable) root.startFacePam();
            });
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
