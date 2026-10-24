# Handoff for the next agent (updated 2026-10-25 00:12)

The user is low on tokens: keep replies short, ask only what blocks you.

## Read these first (all in `~/dotfiles/docs/`)
- `PROGRESS.md`: full dated log of every step, decision and gotcha. Newest entries are just above
  `## Decisions`; `## Next steps` is at the end. **Append an entry after every step.**
- `USER_GUIDE.md`: what the user has: keybinds (before/after), bar items, launcher, config changes. Keep it in sync.
- `NIXOS_NOTES.md`: system-level notes (UWSM vs plain session, packages to remove, PAM, nm-applet, KWallet, calendar events, TLP NOPASSWD).
- `HANDOFF.md`: this file. Update all four `.md` files in `~/dotfiles/docs/` as you go.
- Note: the old `~/hypr-cosmic-shell/` project directory has been removed now that everything lives on git branches.

## Where the real work is
- `~/dotfiles` branch `hypr-cosmic-shell`: `config/hypr` (Lua config), `config/quickshell` (the shell), and `docs/`
  (`PROGRESS.md`, `USER_GUIDE.md`, `NIXOS_NOTES.md`, `HANDOFF.md`).
  Symlinked into `~/.config/hypr` and `~/.config/quickshell`. Commit per feature with `git commit -m ... -- <your paths>`.
  The user's own uncommitted files (e.g. `config/hypr/conf/keyboard.lua`) are theirs: never commit them unless asked.
- `~/Nix` branch `hypr-cosmic-shell`: `system/matevono/hyprland-desktop.nix`, `system/matevono/calendar-events.nix`,
  `system/matevono/configuration.nix`. Check `git diff` before touching; never run `nixos-rebuild switch` (needs root, user does it).

## Working rules learned the hard way
- Wrap every `qs`, `hyprctl`, `busctl`, `systemctl` call in `timeout N`; hung IPC calls blocked earlier turns.
- Restart the shell with `~/.config/hypr/scripts/restart-shell.sh`. New directories under `config/quickshell`
  need a full restart (hot reload says "module not installed").
- My tool shell has NoNewPrivs: no `pkexec`/`sudo`, and never start long-running session processes from it
  (use `hyprctl dispatch 'hl.dsp.exec_cmd("...")'`). `/proc/<pid>/environ` of user processes is unreadable.
- **Screenshots / temporary test images**: ALWAYS place any `grim` / ImageMagick test screenshots or scratch images
  in `/tmp` or `$XDG_RUNTIME_DIR` (never in `~/dotfiles` or the home directory).
- Verify UI by `timeout 5 qs ipc call bar toggle <name>` + `grim /tmp/...` + `nix shell nixpkgs#imagemagick -c magick` crop.
- QML: never name a property `onXxx`; avoid binding loops; text weight goes through `StyledText` (sets styleName);
  icons are Material Symbols via `Icon`; all colors/sizes from `Theme.qml`.
- Don't fix problems the display manager / UWSM already solves. The user runs "Hyprland (uwsm-managed)".
- Never ask for or handle passwords (Nextcloud app password: the user types it into GNOME Calendar themselves).

## State to be aware of
- Recently completed (all committed on `~/dotfiles` branch `hypr-cosmic-shell`):
  - **Nextcloud / EDS calendar events** (`cf8bdc2` in dotfiles, `609092b` in Nix): `services/CalendarEvents.qml`, `Clock.qml`, `scripts/calendar-events.py`.
  - **Battery & Quick Settings power mode selector** (`712f2a4`, `20db4c6` in dotfiles; `8e05413` in Nix): `services/PowerProfile.qml` wrapping `~/dotfiles/scripts/tlpmodes.sh`.
  - **Launcher `!` Quickshell apps & Bar Settings (`!bar`)** (`6bdba0e`): `services/BarConfig.qml`, `bar/BarSettingsWindow.qml`, standalone centered floating `PanelWindow` fallback in `components/Popup.qml`.
  - **`hyprlock` & Media fixes** (`a960e00`): removed dark `$card` shape behind password box, fixed brace-free `playerctl` loop in `hyprlock-gen.py` so track info never shows `"Sample Text"`, moved `playerctl pause-all` to `before_sleep_cmd` in `hypridle.conf`, filtered idle `kdeconnect` in `services/Media.qml`.
  - **Low-battery notifications** (`1ef2516`): `< 20%` (normal) and `< 10%` (critical) in `osd/OsdTriggers.qml`.
  - **Floating desktop portal / screen-share pickers** (`cf7f29d`): `hyprland-share-picker` & `xdg-desktop-portal-*` in `conf/windowrules.lua`.
  - **Pop icon theme unification, horizontal workspaces + 4-finger horizontal workspace swipe, and KDE Plasma-style Overview** (`9bae90f`, `7ccb9c9`): `bar/Overview.qml` (`SUPER+Tab` / `SUPER+W`, `Escape` closes, 4-finger vertical swipe up/down follows fingers 1:1 via `hl.dsp.event("hcs_overview:...")` on `socket2`).
  - **COSMIC Minimon-style modular system monitor** (`938601a`, `bbf0aa6`): `services/SystemStats.qml` + `modules/Stats.qml` (CPU, Temp, Memory, Network, Disk, GPU sparklines/rings/labels/icons + multi-page dropdown).
  - **Caffeine right-click interval dropdown & left-click toggle** (`e123361`): `services/Idle.qml` + `modules/Caffeine.qml` (left click toggles on indefinitely or turns off if active; right click opens `Indefinitely` / `15m` / `30m` / `1h` / `2h` / `4h` dropdown with countdown).
  - **Capture & Screen Recording Studio + Hardware/Privacy Peripherals** (`9821877` in dotfiles, `7dd8f2f` in Nix): `services/Recorder.qml`, `bar/CaptureOverlay.qml` (`SUPER+Print`), `modules/RecorderIndicator.qml`, `services/Privacy.qml`, `modules/PrivacyIndicator.qml`, `services/Storage.qml`, `modules/StorageModule.qml`, and Bluetooth battery levels in `services/Bt.qml` + `modules/BluetoothModule.qml`.
  - **Notification toast fade & click-to-focus app activation**: `services/Notifs.qml`, `notifications/Toasts.qml`, `components/NotificationCard.qml`, and `misc.focus_on_activate = true` in `config/hypr/conf/looks.lua`.
- `TZDIR=/etc/zoneinfo` is set in `config/hypr/conf/environment.lua` (NixOS' Hyprland capability wrapper makes glibc
  drop it; GNOME Calendar crashed with `tz != NULL`).
- nm-applet hidden via `~/.config/autostart/nm-applet.desktop` (`Hidden=true`). polkit-gnome likewise (Home Manager).
- Env-sync lines in `autostart.lua` are commented out on purpose (UWSM does it).
