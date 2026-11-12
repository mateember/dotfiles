# Agent Instructions

Context, rules, and conventions for coding agents working in this repository.

## Repository Overview

Personal NixOS dotfiles installed via [`link.sh`](file:///home/mate/dotfiles/link.sh) (symlinks `config/*` into `~/.config/` and `scripts/` into `~/.scripts/`).

```text
dotfiles/
├── link.sh                         # Idempotent symlink installer (prunes stale repo links, backs up dirs)
├── AGENTS.md                       # Agent rules and codebase conventions (this file)
├── README.md                       # Repository overview
├── docs/
│   ├── USER_GUIDE.md               # User guide: keybindings, widgets, apps, scripts
│   └── NIXOS_NOTES.md              # NixOS system-level configuration requirements
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua            # Compositor entry point (monitors, devices, module imports)
│   │   ├── conf/
│   │   │   ├── autostart.lua       # Session startup services (qs, cliphist, hyprsunset, etc.)
│   │   │   ├── environment.lua     # Wayland env vars (TZDIR, BROWSER, QS_ICON_THEME, cursors)
│   │   │   ├── keybinds.lua        # Input config, core & shell IPC binds, hardware keys, lid switch
│   │   │   ├── looks.lua           # Borders, gaps, blur, animations, misc session-lock settings
│   │   │   ├── rules.lua           # Window and layer rules (floating popups, PiP, blur)
│   │   │   └── scrolling.lua       # Scrolling layout, column width rules, touchpad gestures
│   │   ├── scripts/
│   │   │   ├── lock.sh             # Lock screen launcher (transient systemd unit hcs-lock.service)
│   │   │   ├── reassert-cursor.sh  # Re-applies cursor theme after DPMS wake
│   │   │   └── restart-shell.sh    # Cleanly restarts main Quickshell instance (safe while locked)
│   │   ├── hypridle.conf           # Idle timeouts & sleep hooks (hyprlang format)
│   │   └── hyprsunset.conf         # hyprsunset config (schedule logic lives in NightLight.qml)
│   ├── quickshell/
│   │   ├── shell.qml               # Main shell root (bar, wallpaper, overlays, global IPC)
│   │   ├── lock.qml                # Separate lock screen entry point (started by lock.sh)
│   │   ├── Theme.qml               # COSMIC Dark palette, spacing, radii, typography, opacities
│   │   ├── Config.qml              # Initial shell defaults (clock, calendar, weather fallback, wallpaper)
│   │   ├── bar/                    # Top panel (Bar.qml), Overview, CaptureOverlay, settings windows
│   │   ├── modules/                # 22 modular bar widgets (including modules/background/ & modules/weather/)
│   │   ├── services/               # Singletons (Hypr, Net, Bt, Notifs, Wallpapers, SystemStats, WeatherConfig, etc.)
│   │   ├── components/             # UI primitives (Popup, ListItem, Toggle, StyledText, Icon, etc.)
│   │   ├── launcher/               # Unified launcher (apps, calc, shell commands, emoji, !applets)
│   │   ├── lock/                   # Wayland session lock (LockScreen.qml, LockSurface.qml)
│   │   ├── notifications/          # Toast overlay (Toasts.qml)
│   │   ├── osd/                    # On-screen display (OsdWindow.qml, OsdTriggers.qml)
│   │   ├── polkit/                 # Polkit authentication prompt (PolkitPrompt.qml)
│   │   ├── quicksettings/          # Quick Settings panel (QuickSettings.qml)
│   │   ├── wallpaper/              # Multi-mode wallpaper renderer (Wallpaper.qml, WallpaperScene.qml, shaders/)
│   │   └── scripts/                # capture.sh, calendar-events.py, hardware-status.py, hungaromet.py
│   ├── fish/                       # Fish shell config, aliases, functions, completions
│   ├── kitty/                      # Kitty terminal configuration
│   ├── nvim/                       # Neovim (Lazy.nvim) configuration
│   ├── Kvantum/, qt5ct/, qt6ct/    # Qt & KDE COSMIC Dark theming + make-cosmic-shell-theme.py
│   ├── fastfetch/, distrobox/, winapps/
└── scripts/                        # Utility scripts (tlpmodes.sh, bingpaper.sh, sunshine.sh)
```

## Working Rules

1. **Keep responses concise**: Be direct without conversational filler. Format file paths and symbols as clickable `file://` markdown links.
2. **Use command timeouts**: Wrap interactive or IPC CLI commands (`qs`, `hyprctl`, `systemctl`, `busctl`) in a timeout (e.g. `timeout 5 ...`) so commands cannot hang.
3. **Do not start session processes directly from a restricted shell**: Tool shells with `NoNewPrivs=1` break setuid helpers (`unix_chkpwd`, `polkit-agent-helper-1`). Start long-running session processes via [`restart-shell.sh`](file:///home/mate/dotfiles/config/hypr/scripts/restart-shell.sh), `systemctl --user`, or `hyprctl dispatch 'hl.dsp.exec_cmd(...)'`.
4. **Preserve user edits**: Never revert, overwrite, stage, or commit personal/uncommitted changes (such as [`config/fish/config.fish`](file:///home/mate/dotfiles/config/fish/config.fish) or input sensitivity in [`config/hypr/conf/keybinds.lua`](file:///home/mate/dotfiles/config/hypr/conf/keybinds.lua)) unless explicitly requested. Leave [`docs/kiro.txt`](file:///home/mate/dotfiles/docs/kiro.txt) untouched.
5. **Scratch files & screenshots**: Place temporary scripts, test outputs, and screenshots (`grim`) in `/tmp` or `$XDG_RUNTIME_DIR`—never in `~/dotfiles` or `~`.
6. **Testing & live sessions**:
   - Do not run nested Hyprland. Verify Hyprland config with `Hyprland --verify-config` or `hyprctl configerrors`, and inspect Quickshell logs with `timeout 3 qs log`. Note that `Hyprland --verify-config` checks config keys and rules, not Lua dispatcher argument tables.
   - Never move or delete files actively loaded by the running session without care.
   - Use anchored patterns (e.g. `pkill -f '^...'`) if killing processes so a shell command does not match its own command line.
7. **Keep docs in sync**: Update [`docs/USER_GUIDE.md`](file:///home/mate/dotfiles/docs/USER_GUIDE.md) or [`docs/NIXOS_NOTES.md`](file:///home/mate/dotfiles/docs/NIXOS_NOTES.md) when making user-visible or system-dependency changes.
8. **Git workflow**: Always commit completed changes to git (and create a new branch when needed, e.g., for larger features or isolated experiments), while still keeping unrelated personal/uncommitted changes out of commits unless explicitly requested.

## Architecture & Coding Conventions

### Hyprland (Lua Mode)
- Hyprland uses Lua config ([`hyprland.lua`](file:///home/mate/dotfiles/config/hypr/hyprland.lua)). In Lua mode, `hyprctl dispatch` and `hyprctl eval` expect Lua expressions (not hyprlang strings). [`hypridle.conf`](file:///home/mate/dotfiles/config/hypr/hypridle.conf) and [`hyprsunset.conf`](file:///home/mate/dotfiles/config/hypr/hyprsunset.conf) remain in hyprlang format.
- **Hardware cursors & DPMS**: Keep hardware cursors enabled in [`looks.lua`](file:///home/mate/dotfiles/config/hypr/conf/looks.lua) (do not set `cursor:no_hardware_cursors = true`). Hyprland 0.57 / Aquamarine 0.16 clears the DRM cursor plane on DPMS off and does not re-upload it on pure pointer motion; [`reassert-cursor.sh`](file:///home/mate/dotfiles/config/hypr/scripts/reassert-cursor.sh) re-applies the cursor theme on resume/wake.
- **Session lock restore**: Keep `misc.allow_session_lock_restore = true` in [`looks.lua`](file:///home/mate/dotfiles/config/hypr/conf/looks.lua) and `inhibit_sleep = 3` in [`hypridle.conf`](file:///home/mate/dotfiles/config/hypr/hypridle.conf).

### Quickshell (`config/quickshell/`)
- **Two separate Quickshell instances**:
  - Main shell ([`shell.qml`](file:///home/mate/dotfiles/config/quickshell/shell.qml)): owns D-Bus singletons (`org.freedesktop.Notifications`, StatusNotifier tray) and layer surfaces (`hcs-bar`, `hcs-wallpaper`, etc.). Always restart it with `~/.config/hypr/scripts/restart-shell.sh` (or `--reload-hyprland`) so duplicate instances do not conflict.
  - Lock screen ([`lock.qml`](file:///home/mate/dotfiles/config/quickshell/lock.qml)): runs as transient systemd user unit `hcs-lock.service` launched by [`lock.sh`](file:///home/mate/dotfiles/config/hypr/scripts/lock.sh), isolated from bar restarts/crashes, and exits after unlock. Uses two parallel `PamContext` conversations (`qs-lock` for instant `pam_unix` password verification and `qs-lock-face` for Howdy IR probing) plus `lockForSleep`/`wakeFromSleep` to prevent Howdy from unlocking right before suspend.
- **Hot reload vs. restart**: Saving existing `.qml` files triggers hot reload; adding a new subdirectory under `config/quickshell/` requires restarting via `restart-shell.sh`.
- **QML conventions**:
  - Never name a custom property starting with `onXxx` (Qt treats `on<Capital>` as signal-handler syntax).
  - Use [`StyledText`](file:///home/mate/dotfiles/config/quickshell/components/StyledText.qml) instead of plain `Text` so `font.weight` maps properly to Fira Sans `styleName`.
  - Use [`Icon`](file:///home/mate/dotfiles/config/quickshell/components/Icon.qml) with Material Symbols Rounded glyph names.
  - Source all colors, typography, spacing, and corner radii from [`Theme.qml`](file:///home/mate/dotfiles/config/quickshell/Theme.qml). If you change palette colors in `Theme.qml`, update and re-run [`make-cosmic-shell-theme.py`](file:///home/mate/dotfiles/config/qt6ct/make-cosmic-shell-theme.py) to keep Qt/KDE apps matched.
  - Never call `Hyprland.dispatch()` directly—use [`Hypr`](file:///home/mate/dotfiles/config/quickshell/services/Hypr.qml), which handles Lua vs. hyprlang syntax.
  - Always bind asynchronously populated service properties (`UPower`, `Networking`, `Bluetooth`) rather than reading once on startup.
  - Redirect stdin (`< /dev/null`) when invoking tools like `slurp` from Quickshell `Process` so they do not block on the open pipe.
- **Notable implementation details**:
  - [`Workspaces.qml`](file:///home/mate/dotfiles/config/quickshell/modules/Workspaces.qml) centers workspace digits using `TextMetrics.tightBoundingRect` with an `opticalOffsets` map (`"1": -1.5`) so `"1"` sits centered in the active amber circle.
  - [`ScrollStepper.qml`](file:///home/mate/dotfiles/config/quickshell/components/ScrollStepper.qml) accumulates high-frequency touchpad scroll deltas before stepping workspaces, volume, or brightness.
  - [`NightLight.qml`](file:///home/mate/dotfiles/config/quickshell/services/NightLight.qml) manages its time schedule against the wall clock in QML (instead of `hyprsunset`'s internal timers) so schedule transitions missed during suspend catch up on wake.

### Adding a New Bar Widget
1. Create `config/quickshell/modules/MyWidget.qml` using [`BarButton`](file:///home/mate/dotfiles/config/quickshell/components/BarButton.qml), [`Popup`](file:///home/mate/dotfiles/config/quickshell/components/Popup.qml), `StyledText`, and `Icon`.
2. Register the component and `case` entry in [`Bar.qml`](file:///home/mate/dotfiles/config/quickshell/bar/Bar.qml).
3. Add its metadata and default section (`left`, `center`, or `right`) in [`BarConfig.qml`](file:///home/mate/dotfiles/config/quickshell/services/BarConfig.qml).
4. Restart Quickshell via `~/.config/hypr/scripts/restart-shell.sh`.
