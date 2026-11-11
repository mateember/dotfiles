# Quickshell Lock Screen & Idle Architecture Guide

This document provides project context, technical details, and step-by-step implementation instructions for replacing `hyprlock` (and optionally `hypridle` + `config/hypr/scripts/lock.sh`) with a native **Quickshell (`qs 0.3.2`)** lock screen.

---

## 1. Project Context

### Environment & Stack
- **OS**: NixOS (`hosts/matevono`, UWSM-managed Hyprland session).
- **Compositor**: Hyprland (`>= 0.57`, configured in Lua at `~/dotfiles/config/hypr/`).
- **Desktop Shell**: Quickshell `0.3.2` (`~/dotfiles/config/quickshell/`, symlinked to `~/.config/quickshell/`).
- **Authentication**: PAM + **Howdy** (`pam_howdy.so` is `sufficient` at the top of `/etc/pam.d/hyprlock`, followed by `pam_unix.so`).

### Current Lock & Idle Setup (What We Are Replacing)
1. **`config/hypr/hyprlock-gen.py` & `config/hypr/hyprlock.conf`**:
   - Because `hyprlock` sizes widgets in physical pixels instead of logical scaled pixels, `hyprlock-gen.py` has to generate per-monitor blocks (`eDP-1` at `2.0x` and the external Dell monitor at `1.0x`).
   - Renders: blurred background, big clock (`HH:MM` with amber `:`), date (`%A, %B %-d`), circular amber avatar with user initial, time-of-day greeting (`Good morning/afternoon/evening, <Name>`), pill-shaped password input with PAM failure message, bottom-left MPRIS "Now Playing" label, and bottom-right battery status.
2. **`config/hypr/hypridle.conf` & `config/hypr/scripts/lock.sh`**:
   - Listens to `loginctl lock-session` (D-Bus `Lock` signal) and systemd `PrepareForSleep`.
   - Runs `lock_cmd = ~/.config/hypr/scripts/lock.sh`.
   - `after_sleep_cmd` runs `loginctl lock-session; hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'` because Howdy can recognize the user's face in the few seconds between `before_sleep_cmd` and actual suspend, unlocking the laptop right before it sleeps.
   - `lock.sh` restarts `hypridle` after unlock (when not suspending) so a hands-free Howdy face unlock resets the idle timers.

### Why Move to Quickshell?
- **Automatic DPI scaling**: Quickshell uses logical pixels per `ShellScreen`, eliminating `hyprlock-gen.py` and hardcoded monitor names.
- **Direct access to shell singletons**: The lock screen can directly bind to `Theme.qml`, `Wallpapers.qml` (current wallpaper image), `Mpris.players`, `UPower.displayDevice` (battery), and `Idle.qml` (caffeine) without spawning `playerctl`, `date`, or `/sys/class/power_supply` shell commands every second.
- **First-class Howdy + password state machine**: Quickshell's `PamContext` controls exactly when PAM starts and restarts, avoiding the pre-suspend Howdy race.

---

## 2. Quickshell 0.3.2 Primitives Available

All required modules are compiled into the system's `quickshell-0.3.2` package (`/run/current-system/sw/lib/qt-6/qml/Quickshell/`):

### 2.1 `WlSessionLock` & `WlSessionLockSurface` (`import Quickshell.Wayland`)
Implements the Wayland `ext-session-lock-v1` protocol. When `locked: true`, the compositor blanks all normal windows/layers and displays only the `WlSessionLockSurface` on every connected monitor.

```qml
import Quickshell.Wayland

WlSessionLock {
    id: sessionLock
    locked: LockState.locked   // true locks the session; setting back to false unlocks it

    // Instantiated once per connected monitor automatically
    WlSessionLockSurface {
        id: surface
        // `surface.screen` is the ShellScreen for this monitor
        color: Theme.bg
        // Child QML items go directly here
    }
}
```
- **Properties on `WlSessionLock`**:
  - `locked: bool` — Set to `true` to lock the Wayland session; set to `false` only **after** `PamContext` emits `PamResult.Success`.
  - `secure: bool` (read-only) — `true` once the compositor confirms all monitors are covered by lock surfaces.

### 2.2 `PamContext` (`import Quickshell.Services.Pam`)
Runs a non-blocking PAM conversation against `/etc/pam.d/<config>`.

```qml
import Quickshell.Services.Pam

PamContext {
    id: pam
    config: "hyprlock"   // Reuse /etc/pam.d/hyprlock (already configured in NixOS with Howdy + pam_unix)

    onResponseRequiredChanged: {
        // When pam_unix asks for a password, responseRequired becomes true.
        // Note: pam_howdy runs first and may succeed without ever setting responseRequired!
    }

    onCompleted: result => {
        if (result === PamResult.Success) {
            LockState.unlock()
        } else {
            // PamResult.Failed / PamResult.Error / PamResult.MaxTries
            // Show error animation and restart PAM if still locked
        }
    }
}
```
- **Key `PamContext` API**:
  - Properties: `active: bool`, `config: string`, `user: string`, `message: string`, `messageIsError: bool`, `responseRequired: bool`, `responseVisible: bool`
  - Methods: `start(): bool`, `respond(text: string): void`, `abort(): void`
  - Signals: `completed(PamResult.Enum result)`, `error(PamError.Enum error)`, `pamMessage()`

> **Important Howdy Behavior with `PamContext`**:
> Because `/etc/pam.d/hyprlock` has:
> ```pam
> auth sufficient pam_howdy.so
> auth sufficient pam_unix.so likeauth try_first_pass
> ```
> Calling `pam.start()` immediately activates the IR camera via Howdy!
> - If Howdy recognizes your face, `pam.onCompleted(PamResult.Success)` fires without `responseRequired` ever becoming `true`.
> - If Howdy times out (~4–5s) or fails to see a face, PAM moves to `pam_unix.so`, which sets `pam.responseRequired = true` and waits for `pam.respond(password)`.
> - **Crucial improvement over `hyprlock`**: If the user already typed their password while Howdy was scanning, buffer the submitted password in QML and call `pam.respond(bufferedPassword)` as soon as `responseRequired` becomes `true` (or let the user press a key to trigger `pam.start()` if you don't want Howdy scanning while the screen is off/sleeping).

### 2.3 `IdleMonitor` (`import Quickshell.Wayland`)
Implements `ext-idle-notify-v1` (replaces `hypridle`'s timeout listeners if desired):

```qml
import Quickshell.Wayland

IdleMonitor {
    timeout: 245                // seconds
    respectInhibitors: true     // automatically respects Bar's IdleInhibitor (Caffeine) & fullscreen video
    onIsIdleChanged: if (isIdle) LockState.lock()
}
```

---

## 3. Recommended Architecture

### Option A (Recommended): Quickshell Lock Screen + Keep `hypridle` for Sleep/Logind Signals
Keep `hypridle` solely as the thin bridge for `loginctl lock-session`, `before_sleep_cmd`, and `after_sleep_cmd`, and have it call Quickshell IPC:
- `lock_cmd = qs ipc call lock lock`
- `before_sleep_cmd = playerctl pause-all; qs ipc call lock lockForSleep`
- `after_sleep_cmd = qs ipc call lock wakeFromSleep; hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'`

**Why this solves the Howdy pre-sleep unlock bug cleanly:**
When `lockForSleep` is called (`before_sleep_cmd`), `LockState` sets `locked = true` and `sleeping = true`, which puts up the lock screen **without calling `pam.start()` yet**. Because `pam.start()` isn't called until `wakeFromSleep` (or until the user presses a key / moves the mouse), Howdy never turns on the camera while the lid is closing or while the laptop is entering suspend! Then on `wakeFromSleep`, `LockState` sets `sleeping = false` and calls `pam.start()`, so Howdy scans your face as soon as you open the laptop.

### Option B: Full Replacement (Quickshell Lock Screen + `IdleMonitor`, Remove `hypridle`)
Use `IdleMonitor` instances inside Quickshell for the 245s lock, 250s DPMS off, and 600s `systemctl suspend` timeouts. Note that if you drop `hypridle`, `loginctl lock-session` will no longer trigger the lock unless a D-Bus listener for `org.freedesktop.login1.Session.Lock` / `PrepareForSleep` is running, so keybinds (`SUPER+CTRL+L`, Power menu Lock) should call `qs ipc call lock lock` directly.

---

## 4. Step-by-Step Implementation Instructions

### Step 1: Create `config/quickshell/lock/LockScreen.qml`
Create a new folder `config/quickshell/lock/` with `qmldir` (`module qs.lock` / `LockScreen 1.0 LockScreen.qml`) and `LockScreen.qml`.

`LockScreen.qml` should contain:
1. **State & IPC (`IpcHandler { target: "lock" }`)**:
   - `property bool locked: false`
   - `property bool sleeping: false`
   - `property bool authenticating: false`
   - `property string errorText: ""`
   - `property string pendingPassword: ""`
   - Functions:
     - `lock()`: sets `locked = true`, `sleeping = false`, `errorText = ""`, starts PAM (`pam.start()`).
     - `lockForSleep()`: sets `locked = true`, `sleeping = true`, `errorText = ""`; if `pam.active`, calls `pam.abort()` so Howdy does **not** unlock the machine right before suspend.
     - `wakeFromSleep()`: sets `locked = true`, `sleeping = false`; starts `pam.start()` so Howdy scans on wake.
2. **`PamContext`**:
   - `config: "hyprlock"`
   - When `responseRequired` becomes `true`, if `pendingPassword !== ""`, immediately call `pam.respond(pendingPassword)` and clear `pendingPassword`.
   - `onCompleted`:
     - On `PamResult.Success`: set `locked = false`, `pendingPassword = ""`, `errorText = ""`.
     - On failure: set `errorText = pam.message || "Authentication failed"`, trigger shake animation on the input field, and call `pam.start()` again so the user can retry.
3. **`WlSessionLock` & `WlSessionLockSurface`**:
   - Inside `WlSessionLockSurface`, render the COSMIC Dark lock UI using `Theme.qml`:
     - **Background**: `Image` showing `Wallpapers.current` with `MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0; brightness: -0.15 }` (from `QtQuick.Effects`) or a dark translucent overlay.
     - **Clock & Date**: Centered above the avatar, updated by a `Timer { interval: 1000; running: root.locked; repeat: true }`. Bold hours, `Theme.accent` (`#ffad00`) colon, light minutes.
     - **Avatar & Greeting**: `64x64` circle (`radius: 32`, `color: Theme.accent`) with the user's uppercase first initial, and `"Good morning/afternoon/evening, <Name>"` below it.
     - **Password Input Pill**: Only needs keyboard focus on the focused monitor (`surface.screen.name === Hyprland.focusedMonitor?.name`). Shows `"Scanning face…"` while `pam.active && !pam.responseRequired`, or `"Enter password"` once ready, and submits on `Enter`. Includes a "Retry face unlock" button (`IconButton` with `face` icon) that calls `pam.abort(); pam.start()`.
     - **Bottom Status Row**:
       - Bottom-left: binds to `Quickshell.Services.Mpris` (`Mpris.players.values`) to show the active track icon + `artist – title`.
       - Bottom-right: binds to `Quickshell.Services.UPower` (`UPower.displayDevice`) to show the battery icon and percentage.

### Step 2: Register `LockScreen` in `config/quickshell/shell.qml`
1. Import `qs.lock` at the top of [`config/quickshell/shell.qml`](file:///home/mate/dotfiles/config/quickshell/shell.qml).
2. Instantiate `LockScreen {}` alongside `PolkitPrompt {}` and `QuickSettings {}`.

### Step 3: Enable Crash Recovery in Hyprland (`config/hypr/conf/looks.lua`)
If Quickshell is restarted (`SUPER+SHIFT+R`) or crashes while `WlSessionLock` is active, Wayland's `ext-session-lock-v1` protocol keeps the screen locked on a red/black recovery screen for security.
In [`config/hypr/conf/looks.lua`](file:///home/mate/dotfiles/config/hypr/conf/looks.lua), ensure `misc` has:
```lua
misc = {
    allow_session_lock_restore = true,
}
```
With `allow_session_lock_restore = true`, when Quickshell restarts (`qs`), its `WlSessionLock` can re-acquire the lock session cleanly. Also avoid running `restart-shell.sh` while locked.

### Step 4: Wire Up `hypridle.conf`, Keybinds, and Power Menu
1. **[`config/hypr/hypridle.conf`](file:///home/mate/dotfiles/config/hypr/hypridle.conf)**:
   ```ini
   general {
       lock_cmd = qs ipc call lock lock
       before_sleep_cmd = playerctl pause-all; qs ipc call lock lockForSleep
       after_sleep_cmd = qs ipc call lock wakeFromSleep; hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
   }
   ```
2. **[`config/hypr/conf/keybinds.lua`](file:///home/mate/dotfiles/config/hypr/conf/keybinds.lua#L52)**:
   Keep `SUPER + CTRL + L` as `loginctl lock-session` (which triggers `hypridle`'s `lock_cmd`), or bind it directly to `qs ipc call lock lock`.
3. **Remove Legacy Files (Once Verified)**:
   - Delete `config/hypr/scripts/lock.sh`
   - Delete `config/hypr/hyprlock-gen.py` and `config/hypr/hyprlock.conf` (after backing up any styling tweaks)

---

## 5. Verification Checklist

1. **Syntax & Load Check**:
   - Restart Quickshell: `timeout 8 ~/.config/hypr/scripts/restart-shell.sh`
   - Check logs: `timeout 3 qs log` (verify zero QML errors).
2. **Manual Lock (`qs ipc call lock lock`)**:
   - Confirm both monitors (`eDP-1` and external monitor if connected) are covered and scaled properly.
   - Confirm Howdy IR camera activates and unlocks hands-free.
3. **Password Fallback**:
   - Cover the camera, run `qs ipc call lock lock`, wait for Howdy to time out (or type immediately), enter password, and press `Enter`.
   - Test wrong password → verify shake animation and retry.
4. **Sleep / Wake Cycle (`systemctl suspend`)**:
   - Sit in front of the laptop and run `systemctl suspend`.
   - Verify `lockForSleep` locks the screen **without** triggering Howdy before suspend completes.
   - Wake the laptop → verify `wakeFromSleep` starts PAM/Howdy on wake and unlocks cleanly.
