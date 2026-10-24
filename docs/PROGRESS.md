# Work log: hypr-cosmic-shell

> **Agent handoff:** read `HANDOFF.md` first (rules, state, and the Nextcloud calendar plan).


This file records everything done so far, the decisions made, and what comes next,
so the work can be continued from any client. Update it after every step.

Original request: build a COSMIC-themed Quickshell desktop shell for Hyprland, entirely
inside `~/hypr-cosmic-shell/`. Never write to `~/.config/hypr`, `~/.config/quickshell`,
`/etc/nixos`, or any other live config. No Home Manager. System-level changes go into
`NIXOS_NOTES.md` only.

Milestones: (a) flake + run.sh + theme + bar skeleton (workspaces, clock),
(b) remaining bar modules, (c) launcher, (d) notifications + OSDs,
(e) lock/power/quick settings, (f) polish + README.md + NIXOS_NOTES.md.
After each milestone: launch, check quickshell logs for QML errors, tell the user how to test.

---

## Status

| Step | State |
|---|---|
| Step 0: investigation (read-only) | done, findings below, reported to user |
| API reference for Quickshell 0.3.2 extracted | done (`dev/quickshell-0.3.2-api.txt`) |
| (a) flake, run.sh, Theme.qml, bar skeleton, hypr config copy | done, verified on COSMIC and real Hyprland 0.56.2 |
| Lua migration of hypr/ config | done, running live since 16:42 (mouse-drag binds: user to test by hand) |
| (b) bar modules | done; waiting on user to confirm popup clicks work |
| (c) launcher | done |
| wallpaper slideshow (from e) | done |
| (d) notifications + OSD | done (polkit prompt untested) |
| pickers, kdeconnect, polkit, kbd backlight | done |
| niri-style scrolling + gestures | done (gestures untested by hand) |
| system install (dotfiles + ~/Nix branches) | committed + built, not switched |
| night light, quick settings, media card | done (dotfiles 38677b7) |
| system install | live since 18:42 (UWSM session) |
| (f) polish, README | not started |

---

## Log

### 2026-10-24 15:56 – Step 0 investigation (read-only, nothing modified)
- Read `~/.config/hypr/hyprland.conf` and `conf/{keyboard,windowrules,autostart,looks,environment}.conf`,
  `hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`, `hyprsunset.conf`, `scripts/*`.
- Read `~/.config/cosmic/com.system76.CosmicTheme.Dark/v2/*`, `.Light`, `.Dark.Builder`,
  `CosmicTk`, `CosmicPanel.Panel`, `CosmicAppletTime`, Tempest weather applet, `CosmicBackground`.
- Checked environment (see "System facts").
- Reported findings + plan + 7 questions to the user.

### 2026-10-24 ~16:00 – User answers
- "I could install hyprland globally, but I don't want to switch to it right now."
  → Decision: no global install needed. The flake provides Hyprland and `run-nested.sh`
  runs it nested in a window inside the COSMIC session.
- The other 6 questions were not answered. Proceeding with the proposed defaults
  (listed under "Decisions"). User can override any of them.

### 2026-10-24 ~16:02 – API verification
- Instead of guessing from web docs, dumped the real API from the installed package's
  `.qmltypes` files: `/nix/store/p4fqvcdsgq2rds0f1k3gwqp7k50vfz8r-quickshell-0.3.2/lib/qt-6/qml/Quickshell`.
- Script: `dev/qmltypes-dump.py <that path>` → `dev/quickshell-0.3.2-api.txt`
  (all types with properties, methods, signals, enums). Use this before using any type.
- QML-defined types (not in qmltypes): `Io/FileView.qml` (adds `path`, `preload`,
  `blockLoading`, `printErrors`, `text()`, `data()`), `Widgets/IconImage.qml`
  (`source`, `implicitSize`, `asynchronous`, `mipmap`), ClippingRectangle,
  WrapperItem, WrapperMouseArea, WrapperRectangle.
- Confirmed from guide: `import qs.<dir>` imports relative to the folder containing
  `shell.qml`; singletons use `pragma Singleton` + `Singleton {}`.
- Started user-requested work log (this file) in the project folder.

### 2026-10-24 ~16:10 – Milestone (a) part 1: flake, run scripts, hypr config copy
- `flake.nix`: nixpkgs pinned to `fe13242281a67641c0102cdb1087f0ebe586c7df` (= `nixos-version --revision`).
  Same quickshell store path as the system one (`p4fq…-quickshell-0.3.2`), so no rebuild.
  Outputs: `devShells.default`, `apps.env` (runs a command with all deps + fonts on PATH),
  `apps.default` (runs quickshell on `$HCS_ROOT/shell`).
  Fonts via a generated `FONTCONFIG_FILE` that includes `/etc/fonts/fonts.conf` + project fonts.
  Verified font family names: "Material Symbols Rounded", "Fira Sans", "JetBrainsMono Nerd Font".
- `run.sh` (shell on current session, `--no-notify` flag). (A `run-nested.sh` existed briefly; removed, see 16:22.)
- `hypr/`: copied `hyprland.conf`, `conf/*.conf`, `hypridle.conf`, `hyprsunset.conf`, `scripts/{monitor_check,hyprestart}.sh`.
  Changes (all marked `HCS` in comments):
  - `hyprland.conf`: `$HCS = ~/hypr-cosmic-shell`, sources point at `$HCS/hypr/conf/`, sources new `conf/shell.conf` last.
  - `conf/autostart.conf`: waybar, dunst, swww.sh commented out; hypridle uses `-c $HCS/hypr/hypridle.conf`.
  - `conf/environment.conf`: identical to the original (nested-only guards were removed again at 16:22).
  - `conf/keyboard.conf`: comments flag the broken binds (kept verbatim).
    **SUPER J**: `togglesplit` dispatcher no longer exists in Hyprland 0.56 → `layoutmsg, togglesplit` (same key, same action).
  - `conf/looks.conf`: `dwindle:pseudotile` option removed in 0.55 → commented out.
  - `conf/shell.conf` (new): `exec-once = qs -p $HCS/shell`, the 6 new binds, layerrules for blur on `hcs-*` namespaces.
  - `hypridle.conf`: lock_cmd → shell IPC lock, falls back to hyprlock.
- Verified: `Hyprland --verify-config -c hypr/hyprland.conf` → no errors.
  (The original config reports the same 2 errors on 0.56; the original was not touched.)
  Note: `--verify-config` does validate layerrule fields (tested with a bogus field).

---

### 2026-10-24 ~16:12 – Milestone (a) part 2: theme + bar skeleton, tested on COSMIC
- Wrote `shell/shell.qml` (ShellRoot + Variants over Quickshell.screens), `shell/Theme.qml`,
  `shell/Config.qml`, `shell/services/Time.qml`, `shell/components/{Icon,StyledText,BarButton}.qml`,
  `shell/modules/{Workspaces,Clock}.qml`, `shell/bar/Bar.qml` (PanelWindow, namespace `hcs-bar`).
- Bugs found and fixed:
  - `services/Time.qml` lacked `import qs` → `Config is not defined`.
  - **Theme property names `onBg`/`onAccent`/`onPrimary` silently became black**: QML treats
    `on<Capital>` as signal-handler syntax. Renamed to `fgOnBg`/`fgOnAccent`/`fgOnPrimary`.
    **Never name a property `onXxx`.**
- Sizes adjusted against the user's real COSMIC panel (screenshot): barHeight 32, bar font 16,
  workspace cell barHeight+4 wide, bold numbers.
- `./run.sh` on COSMIC: only log warning is the expected `$HYPRLAND_INSTANCE_SIGNATURE is unset`.
- Screenshot: `dev/screenshots/a-bar-cosmic.png` (top = real COSMIC panel, below = ours).

### 2026-10-24 ~16:15–16:22 – Nested Hyprland attempt (abandoned on user request)
- Findings, in case it's ever retried: Hyprland 0.56 (aquamarine) needs `wl_compositor` ≥ 6 and
  `xdg_wm_base` ≥ 6. COSMIC offers wl_compositor 5 → `CBackend::create() failed`. Weston: 5.
  cage: xdg_wm_base 5. labwc offers 6/6 and Hyprland started inside it (layer `hcs-bar` was mapped),
  but the user only saw an empty labwc window.
- **User instruction (16:22): don't try nested Hyprland. If a live Hyprland is needed, stop and tell
  the user how to start it normally with the config. Save progress periodically.**
- Cleanup: killed all labwc/cage/weston/Hyprland/quickshell test processes by PID, removed
  `run-nested.sh`, removed `HCS_NESTED` guards from the config copy and Config.qml,
  removed /tmp test files. Crash reports left by the attempts are in `~/.cache/hyprland/hyprlandCrashReport*.txt`
  (written by Hyprland itself; safe to delete).
- Added `start-hyprland.sh`: run from a TTY; `nix run path:<root>#env -- start-hyprland -- -c <root>/hypr/hyprland.conf`.
  Refuses to run inside a graphical session. Not yet run by the user.
- Added `NIXOS_NOTES.md` (programs.hyprland, optional ly session entry, power-profiles-daemon, i2c for ddcutil).
- Verified after cleanup: `Hyprland --verify-config` no errors; `./run.sh` loads cleanly.

### 2026-10-24 16:29 – User is on real Hyprland now; Lua migration requested
- User started Hyprland with `./start-hyprland.sh` from TTY3. My tool session now runs inside it
  (`WAYLAND_DISPLAY=wayland-2`, `XDG_CURRENT_DESKTOP=Hyprland`). COSMIC still runs on tty1 (wayland-1).
- Checked under real Hyprland 0.56.2: `hyprctl configerrors` empty, layer `hcs-bar` mapped,
  `qs ... log` shows no QML errors. **Milestone (a) verified on Hyprland.**
- User request: hyprlang `.conf` goes away in 0.57 → migrate the project's hypr config to Lua.
- Research: hypr.land/news/26_lua: Lua since 0.55, hyprlang supported 1–2 releases after that.
  `hyprland.lua` is preferred over `hyprland.conf` if both exist. hypridle/hyprlock/hyprsunset KEEP hyprlang.
- Saved authoritative references from the Hyprland 0.56.2 package into dev/:
  `dev/hyprland-0.56.2-default.lua` (official example config), `dev/hl-0.56.2.meta.lua` (API stubs).
  Dispatcher args/window-rule effects are untyped in stubs → take them from wiki.hypr.land/0.56.0.

### 2026-10-24 ~16:45 – Lua migration: research results (before writing files)
- References saved: `dev/wiki/*.md` (raw wiki markdown from hyprwm/hyprland-wiki HEAD, lowercase paths
  `content/configuring/core/...`), `dev/hl-0.56.2.meta.lua`, `dev/hyprland-0.56.2-default.lua`.
- `Hyprland --verify-config -c x.lua` validates config keys, rule fields, errors in required files.
  It does NOT validate dispatcher argument tables (tested `bogusarg` → "config ok").
- `require("conf.mod")` resolves relative to the config file's directory (tested).
- In Lua mode `hyprctl dispatch` / `hyprctl keyword` expect Lua → lid-off bind, monitor_check.sh,
  hypridle dpms commands and Quickshell `Hyprland.dispatch()` must use Lua syntax
  (Quickshell exposes `Hyprland.usingLua`).
- `hyprctl reload full-reset` can switch hyprlang↔lua live; not used (user's live session).
- Live bind baseline: `dev/binds-hyprlang.txt` (66 binds) via `hyprctl binds -j | python3 dev/dump-binds.py`.
  Shows `$altMod`/`$shiftMod`/`$mainMod_SHIFT` DO resolve to ALT/SHIFT/SUPER+SHIFT (my earlier note was wrong).

### 2026-10-24 ~17:00 – Lua migration done (verified offline; NOT yet booted in Lua mode)
- New: `hypr/hyprland.lua` + `hypr/conf/{keyboard,windowrules,looks,environment,autostart,shell}.lua`.
  `HCS` (project root) is derived from the config file's own path.
  Mapping: exec-once → `hl.on("hyprland.start")`; `exec` (hyprsunset) → start + `config.reloaded`;
  binde→repeating, bindr→release, bindm→mouse, bindl→locked; movetoworkspace → move{follow=true};
  killactive → window.close(); fullscreen 0 → fullscreen{mode="fullscreen"}; togglesplit → hl.dsp.layout.
  Lid binds are Lua functions now (monitor_check.sh logic inlined, `hyprctl keyword` doesn't take hyprlang in Lua mode)
  → `hypr/scripts/` copies deleted (they were unused copies; originals untouched).
- `hypr/hyprland.conf` + `hypr/conf/*.conf` kept as LEGACY, frozen, for `./start-hyprland.sh --legacy`.
  (I briefly moved them while the user's session was running from them; moved back within seconds,
  `hyprctl configerrors` stayed empty. Lesson: never move files the live session loaded.)
- `hypr/hypridle.conf`: dpms commands → `hyprctl dispatch 'hl.dsp.dpms({ action = ... })'` (Lua mode only;
  the currently running hypridle keeps its old config until restart). hypridle/hyprlock/hyprsunset stay hyprlang.
- `start-hyprland.sh`: default config is now `hypr/hyprland.lua`; `--legacy` uses the .conf.
- Shell: new `shell/services/Hypr.qml` singleton → dispatch in Lua or hyprlang syntax based on
  `Hyprland.usingLua`. Workspaces.qml uses it. **Never call Hyprland.dispatch() directly; use Hypr.***.
- Verification:
  - `Hyprland --verify-config -c hypr/hyprland.lua` → "config ok".
  - `dev/lua-binds-check.lua` (stub `hl`, run with nixpkgs#lua) → `dev/binds-lua.txt`; diff vs
    `dev/binds-hyprlang.txt`: all 66 binds identical except the 2 lid binds (now Lua functions).
  - Shell hot-reloaded in the live session with no QML errors (fixed a reload warning in Time.qml).
- Waiting on user: log out (SUPER M) and run `./start-hyprland.sh` again from the TTY to boot the Lua config.

### 2026-10-24 16:42 – Booted Lua config (user restarted Hyprland)
- Session: `Hyprland -c .../hypr/hyprland.lua`. `hyprctl configerrors` empty. hypridle (project copy),
  hyprsunset, cliphist watchers, shell (hcs-bar) all running.
- Live binds (`dev/dump-binds.py`) match `dev/binds-hyprlang.txt` in mods+keys for all 66; dispatchers show as
  `__lua <n>` (Lua binds are opaque in JSON). The `mouse` flag is not reported for Lua binds at all
  (even a fresh `{ mouse = true }` bind reads back `mouse=false`) → SUPER+LMB/RMB drag must be tested by hand.
- Tested Lua dispatch strings as Hypr.qml builds them: focus workspace 4 / "m-1" work.
- User won't use COSMIC meanwhile → free to take screenshots of the Hyprland session (wayland-2).
- Starting milestone (b).

### 2026-10-24 ~16:55 – Runtime facts for milestone (b) (probe in /tmp, not kept)
- UPower.displayDevice.percentage is 0..1 (0.49), isLaptopBattery true. WifiNetwork.signalStrength 0..1.
  Services populate asynchronously (first read returns defaults) → always bind, never read once.
- Power profiles: provided by **system76-power** (owns org.freedesktop.UPower.PowerProfiles) → works,
  NIXOS_NOTES corrected (don't enable power-profiles-daemon).
- MPRIS players: Brave, KDE Connect. BT adapter "matevono" with 2 paired headsets.
- `udevadm monitor --udev --subsystem-match=backlight` works as user → event-driven brightness.
- `hyprctl getoption general:layout -j` works in Lua mode; set via `hyprctl eval 'hl.config(...)'`.

### 2026-10-24 ~17:05 – User: uses TLP, skip power profiles entirely
- No power-profile switcher anywhere in the shell (battery popup shows charge/time only).
  Removed the power-profiles section from NIXOS_NOTES.md. Don't add it back.

### 2026-10-24 ~17:00–17:15 – Milestone (b): all bar modules + popups
- Components: Popup (layer-shell PanelWindow, see below), StyledSlider, Toggle, ListItem, IconButton,
  TextField, PopupHeader, Separator. Popup state: services/Popups.qml (one open at a time, id "<name>@<screen>").
- Services: SystemStats (/proc + coretemp by name), Weather (Open-Meteo, cache in Quickshell.cachePath("weather.json"),
  temp file + mv so failures never clobber the cache), Clipboard (cliphist; image thumbnails decoded to cache),
  Idle (caffeine, PersistentProperties), Audio (Pipewire), Brightness (sysfs + brightnessctl, udevadm events; ddcutil
  externals), Battery (UPower, no profiles), Net (Quickshell.Networking), Bt (Quickshell.Bluetooth), Media (Mpris,
  playerctld filtered), Notifs (DND only, server in (d)), Hypr (layout get/set/toggle, exit, IPC `workspaces focus`).
- Modules: Workspaces, ClipboardModule, Caffeine (IdleInhibitor per bar), Stats, WeatherModule (+5-day popup),
  Clock (+MonthGrid calendar), Tray, Display (brightness, monitors, screenshot tiles), TilingLayout (left click toggle
  dwindle/master, right click list), MediaModule, Volume (scroll, middle-click mute, mixer with collapsible device lists
  + per-app streams), BluetoothModule, NetworkModule (inline PSK prompt, right click forgets), BatteryModule,
  NotificationsButton (DND placeholder), PowerButton (2-click confirm for logout/restart/shutdown).
- shell.qml IPC: `bar toggle <name>`, `bar close`, `clipboard toggle`, `notifications toggle`, `power toggle`.
- dev/shoot-popups.sh opens each popup via IPC and screenshots it (dev/screenshots/popups/).
- Gotchas found:
  - A module named `Layout.qml` would shadow QtQuick.Layouts' `Layout.*` attached props → renamed TilingLayout.qml.
  - grabToImage on transparent bg made bold look regular → not a font bug (reverted a fontconfig change).
  - **User report: clicking inside a popup fell through to the window underneath.** Popups were xdg_popups
    (PopupWindow). Rewrote components/Popup.qml as a layer-shell PanelWindow (namespace `hcs-popup`, layer Top,
    keyboardFocus OnDemand while open, ExclusionMode.Ignore), positioned under the button via barWindow.itemRect(),
    height capped to the screen, HyprlandFocusGrab for click-outside. Waiting for user confirmation.
- Open questions: Brave stream showed 150% in the mixer while paused; couldn't cross-check with wpctl (stream gone).
  Tray is empty right now (no SNI apps running) so it's untested.

### 2026-10-24 17:04 – User: replace old apps with shell features, one by one
- Requests: (1) launcher in Quickshell, **replace the old keybinds** (rofi etc.) instead of adding new keys;
  (2) popups get buttons that open the matching app (cosmic-settings <page>, pavucontrol, ...);
  (3) NIXOS_NOTES: list now-unused packages to remove (rofi, ...); (4) wallpaper = random slideshow of
  ~/Pictures/BingWallpaper.
- Facts: `cosmic-settings` has subcommands bluetooth, sound, wireless, network, displays, power, date-time, ...
  cosmic-settings, pavucontrol, gnome-calendar, nm-connection-editor are installed system-wide with the SAME store
  paths as the pinned flake → add them to the flake for free.
- Old apps in users.users.mate.packages (/etc/profiles/per-user/mate): rofi 2.0.0, waybar 0.15.0, wlogout 1.2.2,
  awww 0.12.1. dunst and xembedsniproxy are NOT installed (the original autostart lines silently fail).
  ~/.config has rofi, waybar, dunst, wlogout, waypaper dirs.
- Quickshell icon theme: env `QS_ICON_THEME` (found in binary). COSMIC icon theme is "Pop".
- Plan: SUPER Space → launcher, SUPER SHIFT C → clipboard popup, SUPER L → power menu, SUPER SHIFT R → restart
  shell + reload Hyprland. Drop the interim SUPER A / SUPER SHIFT V / SUPER X binds.

### 2026-10-24 ~17:05–17:30 – App buttons, launcher (milestone c), old binds replaced, wallpaper
- Popups now have header buttons that open the matching app (components/AppButton.qml):
  Bluetooth → `cosmic-settings bluetooth`; Wi-Fi → `cosmic-settings wireless` (+ "Network settings" row →
  `cosmic-settings network`); Sound → `pavucontrol` (tune icon) and `cosmic-settings sound`; Display →
  `cosmic-settings displays`; Battery → `cosmic-settings power`; Calendar → `gnome-calendar` and
  `cosmic-settings date-time`; Media → "Open <player>" (MprisPlayer.raise()).
- Flake: added cosmic-settings, pavucontrol, gnome-calendar, networkmanagerapplet, kitty, pop-icon-theme,
  hicolor-icon-theme; env `QS_ICON_THEME=Pop` + XDG_DATA_DIRS prepend (system dirs kept, so all .desktop apps show).
- Launcher: shell/launcher/Launcher.qml (Scope + LazyLoader PanelWindow, layer Overlay, keyboard Exclusive,
  namespace hcs-launcher, on the focused monitor). Fuzzy ranking + launch counts in
  Quickshell.statePath("launcher-usage.json"). `=expr`/plain math → qalc, Enter copies; `>cmd` runs, Shift+Enter in kitty.
  runInTerminal entries open in kitty. IPC `launcher toggle|open|close`. Icon fallback latch for missing icon files.
  Verified via IPC + wtype + grim: list with icons, "fire" → Firefox, "=2^10*3" → 3072. Shots in dev/screenshots/c-*.png.
- **Old binds replaced (user request), same keys**: SUPER Space → launcher (rofi), SUPER SHIFT C → clipboard
  (rofi+cliphist, removes the typo bind), SUPER L → power menu (wlogout), SUPER SHIFT R → `restart-shell.sh
  --reload-hyprland` (hyprestart.sh). Removed interim SUPER A / SUPER SHIFT V / SUPER X. `HCS_QS` global in hyprland.lua.
- New `restart-shell.sh`: kills the shell and starts it again through `nix run path:<root>#env` (picks up flake changes).
  Ran it: shell restarted with new env, `hyprctl configerrors` empty.
- Wallpaper (user request: random slideshow of ~/Pictures/BingWallpaper): services/Wallpapers.qml (FolderListModel,
  watches the folder, tick every Config.wallpaperIntervalSec = 300 s, IPC `wallpaper next`) + wallpaper/Wallpaper.qml
  (per screen, background layer `hcs-wallpaper`, independent random image per monitor, 1.2 s crossfade, instant when
  a fullscreen window is on that monitor, PreserveAspectCrop). Verified crossfade frame-by-frame.
  Fixed: first-image flag never cleared → no fade.
- Blur layer rule now lists namespaces explicitly (bar/popup/launcher/osd/toast/notifications/quicksettings/power)
  so the wallpaper layer isn't blurred; added `blur_popups`.
- NIXOS_NOTES §3: removable packages (rofi, waybar, wlogout, awww), dunst/xembedsniproxy not installed, old config dirs.
- Known: `Time.qml` reload warning "Unable to assign [undefined] to QDateTime" appears on hot reload only (harmless).

### 2026-10-24 17:15 – User asked: what's missing for a "semi-desktop" Hyprland; how to fix/integrate
- User: COSMIC still running on tty1 is temporary, don't solve conflicts caused by that now.
- Inventory (read-only checks):
  - OK: polkit-gnome agent (user service), kwalletd6/ksecretd Secret Service, gvfs+udisks2, pipewire, kdeconnectd,
    xdg-desktop-portal-hyprland 1.4.1 installed + ~/.config/xdg-desktop-portal/hyprland-portals.conf
    (default hyprland;gtk, FileChooser=cosmic), hyprsunset, hypridle, hyprlock, hyprshot, swappy (flake), thunar, kitty,
    nwg-look, qt6ct + kvantum, hyprdynamicmonitors (config writes ~/.config/hypr/monitors.conf; not started anywhere).
  - Caused by COSMIC running in parallel (ignore for now): xdg-desktop-portal started Oct 22 under COSMIC uses the
    cosmic backend; org.kde.StatusNotifierWatcher owned by cosmic-applets → shell tray empty.
  - Broken in user's config: SUPER B / BROWSER=brave → no `brave` binary, installed browser is `brave-origin`.
    qt6ct icon_theme=breeze-dark not installed. Cursor mismatch: Hyprland env BreezeX-Black vs GTK breeze_cursors.
    GTK icons ePapirus-Dark vs shell Pop.
  - Missing: notification daemon (milestone d), OSDs (d), color picker (hyprpicker), screen recorder (OBS flatpak only),
    emoji picker, xwaylandvideobridge (window rule exists, package not installed), shell lock (e), quick settings (e).
  - ~/.config/autostart: only ibus; XDG autostart isn't run by plain Hyprland (no uwsm).
- Answered with a plan + questions; no files changed in this step.

### 2026-10-24 17:21 – User: next = notifications, color+emoji picker, kdeconnect-indicator, polkit prompts, OSDs
- Constraints: keep Thunar; don't change system config, put packages in the flake.
- Flake: + hyprpicker, kdePackages.kdeconnect-kde (same store path as system), noto-fonts-color-emoji,
  env HCS_EMOJI_FILE=<unicode-emoji>/share/unicode/emoji/emoji-test.txt (3944 fully-qualified).
- Facts: Notification methods expire(), dismiss(), sendInlineReply(). PolkitAgent: path, isRegistered, isActive, flow.
  AuthFlow Identity type isn't exported. org.freedesktop.Notifications currently owned by cosmic-notifications (pid 15536,
  COSMIC still running).
- Planned binds (free keys): SUPER period = emoji picker, SUPER SHIFT P = color picker.

### 2026-10-24 ~17:22–17:40 – Milestone (d) + pickers + polkit + kdeconnect + kbd backlight
- Notifications: services/Notifs.qml (NotificationServer in LazyLoader, keepOnReload, actions/images/markup,
  history = trackedNotifications newest first, toasts max 5, DND hides non-critical, timeouts: app value or 6 s,
  critical sticky, paused on hover), components/NotificationCard.qml, notifications/Toasts.qml (layer Overlay
  `hcs-toast`, top right of focused monitor), notification center in modules/NotificationsButton.qml (clear all, DND).
  Tested with gdbus Notify (normal + critical): toasts + center render, action button shown.
- OSD: services/Osd.qml + osd/OsdWindow.qml (bottom center, click-through `mask: Region {}`, `hcs-osd`) +
  osd/OsdTriggers.qml: volume/mute/mic/sink change, brightness (udev), kbd backlight, caffeine, DND, Wi-Fi, BT,
  layout, plug/unplug. Low battery 20/10/5 % → notification. 3 s startup grace so loads don't flash OSDs.
  Suppressed for a value while its own popup is open.
- Pickers: services/ColorPicker.qml (hyprpicker, IPC `picker color`, SUPER SHIFT P, Color tile in Display popup,
  OSD shows swatch + hex, copied). services/Emoji.qml + launcher ":" mode (IPC `launcher emoji`, SUPER period):
  Enter = copy + wtype into focused window, Shift+Enter copy only.
- Polkit: polkit/PolkitPrompt.qml (PolkitAgent, COSMIC-styled modal on focused monitor, shake on wrong password,
  `hcs-polkit`). polkit-gnome (NixOS user service) is stopped at runtime by conf/shell.lua and restart-shell.sh before
  the shell starts (no system config change). After user's reboot: polkit-gnome inactive, no registration warning.
  **Not yet tested with a real prompt** (my pkexec test was interrupted by the reboot) → user to test.
- kdeconnect-indicator from the flake, started in conf/autostart.lua.
- shell.qml: `_eager` list forces lazy singletons that own IPC targets (ColorPicker, Wallpapers, Notifs, Emoji) to exist.
  Gotcha: new dirs under shell/ need a full restart (`restart-shell.sh`), hot reload says "module not installed".
- User rebooted (17:32) and logged straight into Hyprland (Lua config). cosmic-comp only runs the greeter now.
  Shell owns org.freedesktop.Notifications and org.kde.StatusNotifierWatcher (tray works now).
- Keyboard backlight (user request): platform::kbd_backlight (0..2) via `brightnessctl -d`. Display popup row:
  Low/High + on/off toggle. Per user: NO hardware readback/polling; show last chosen level, persisted in
  Quickshell.statePath("kbd-backlight.json"); toggle restores last "on" level. IPC `kbd cycle|toggle|set N`.

### 2026-10-24 ~17:45 – USER_GUIDE.md + brave-origin
- New USER_GUIDE.md (user request): start/restart, every keybind with before/after, bar items, launcher modes,
  background features, per-file config changes, known issues. **Keep it updated with every user-visible change.**
- User OK'd: SUPER B and BROWSER → `brave-origin` (keyboard.lua, environment.lua).

### 2026-10-24 17:40 – Polkit test attempts
- My tool shell has `NoNewPrivs: 1` → setuid programs (pkexec, sudo) can't elevate from it ("pkexec must be setuid
  root", exit 127). **The agent can't be tested from the tool shell with pkexec; the user must run `pkexec true`
  in their own terminal.** (pkexec in the flake env correctly resolves to /run/wrappers/bin/pkexec.)
- Alternative that needs no setuid: `pkcheck --action-id org.freedesktop.policykit.exec --process $$
  --allow-user-interaction` (asks polkitd, triggers the session's agent, executes nothing). Not run yet.
- User cancelled two test runs; waiting for the user to test by hand.

### 2026-10-24 ~17:42–18:05 – Niri-style workflow (hypr/conf/niri.lua)
- Uses Hyprland's built-in `scrolling` layout (wiki saved: dev/wiki/layouts_scrolling-layout.md, core_binds_gestures.md).
  Loaded via `require("conf.niri")` after looks.lua. Bar layout toggle = scrolling ↔ dwindle.
- Gestures: 3-finger horizontal `scroll_move` (snap to grid), 3-finger vertical `workspace`
  (workspace_swipe_create_new). Workspace animation slidevert. Touchpad gestures need the user to test by hand.
- Binds (only free keys): SUPER CTRL arrows (swapcol / move in column), SUPER SHIFT arrows (focus monitor),
  SUPER SHIFT CTRL arrows (move to monitor), SUPER PgDn/PgUp/U/I (+CTRL = move window) with "r±1",
  SUPER R / CTRL R (colresize ±conf), SUPER ü/ó (∓0.1), SUPER ő/ú (consume_or_expel prev/next), SUPER CTRL C center,
  SUPER SHIFT wheel (layout focus). hu keysyms udiaeresis/oacute/odoubleacute/uacute instead of code:NN
  (code: binds report keycode 0 in Lua, unverifiable). 95 binds, no duplicate combos.
- User requests during this: most apps full width, terminals + file managers half (column_width 1.0 + window rule
  `scrolling_width = 0.5` on a class regex); SUPER F = maximize toggle (fullscreen{mode="maximized",action="toggle"}),
  real fullscreen SUPER SHIFT F. Both tested via dispatch: kitty opens 709 px wide, toggle 709↔1422.
- Found: kitty restores a maximized state → every kitty opened maximized (fs=1) → rule `suppress_event = "maximize"`
  for all windows (`no-self-maximize`).
- Lone narrower-than-screen strip is centered: hard-coded in ScrollTapeController::calculateCameraOffset (0.56.2).
  Wrote a 1-line patch, then **user said: don't left-align, don't patch/recompile Hyprland** → patch deleted, nothing
  in the flake changed. Documented as a limitation.
- Gotcha: `pkill -f "<pattern>"` killed my own tool shell (pattern in its own command line). Use `pkill -f '^kitty …'`.
- Test windows (class hcs-test, ws 7/8/9) closed. User's own windows on ws1/ws6 left alone.

### 2026-10-24 17:57 – Bar scroll too fast; 4-finger workspaces
- New components/ScrollStepper.qml: sums wheel deltas to 120 (one mouse notch) before stepping, optional cooldown.
  Workspaces: cooldown 250 ms. BarButton.scrolled and StyledSlider wheel also go through it (touchpad no longer
  sends dozens of volume/brightness steps). Tested with simulated events: 600-unit touchpad burst → 1 step.
- niri.lua: added 4-finger vertical `workspace` gesture next to the 3-finger one.

### 2026-10-24 18:00 – Workspace indicators = existing workspaces only (user request)
- Workspaces.qml: ids = Hyprland.workspaces with id > 0 on this bar's monitor, sorted. Removed Config.workspaceCount.

### 2026-10-24 18:01 – KWallet check + media right click
- KWallet: kwalletd6 + ksecretd are D-Bus activated on demand (not running until something asks; my isEnabled call
  started them). Enabled, one wallet "kdewallet" (= network wallet), not open. ksecretd owns org.freedesktop.secrets,
  default collection /org/freedesktop/secrets/collection/kdewallet, Locked=true. No pam_kwallet in /etc/pam.d →
  wallet isn't unlocked at login; first app needing a secret triggers KWallet's own password dialog.
  Secret portal: hyprland-portals.conf has no Secret entry → falls back to gtk (gnome-keyring, not installed).
  Not changed anything; reported to user.
- MediaModule: right click (and middle) = play/pause, left = popup.

### 2026-10-24 18:05 – KWallet + user's NixOS config (read-only)
- User's system flake: ~/Nix/flake.nix, host ~/Nix/system/matevono/configuration.nix (uses Home Manager for
  matevono: home/hyprland, rofi, waybar, wlogout, dunst live there). Never modify.
- Already set: pam.services.cosmic-greeter.kwallet.{enable,forceRun}, pam.services.login.kwallet.enable,
  gnome-keyring forced off, polkit-gnome as a custom user service (wantedBy graphical-session.target),
  display manager = cosmic-greeter (ly/sddm/gdm disabled), desktopManager cosmic + gnome.
- User: will log in via the display manager, which unlocks KWallet; no changes wanted. NIXOS_NOTES §4 corrected.
- Open point told to user: pam_kwallet_init (handoff via $PAM_KWALLET5_LOGIN + socat) runs from XDG autostart under
  COSMIC/KDE, not under plain Hyprland. If the wallet still prompts in Hyprland, add it to autostart.lua.

### 2026-10-24 18:07 – Home Manager is not a conflict
- Checked ~/Nix/system/matevono/home/default.nix: ./hyprland, ./waybar, ./dunst, ./rofi, ./wlogout imports are
  commented out (and wayland.windowManager.hyprland.enable = false in hyprland/default.nix). HM doesn't write
  ~/.config/hypr. No switch-over note needed.

### 2026-10-24 18:10 – BUG FIX: idle lock never locked
- `qs ipc call <missing target>` prints "Target not found." but **exits 0**, so hypridle's
  `qs … ipc call lock lock || hyprlock` never fell back → idle/suspend lock did nothing since the Lua switch.
  Fixed: hypridle.conf lock_cmd back to the original (`pidof hyprlock || hyprlock`); SUPER CTRL L →
  `loginctl lock-session` (hypridle's lock_cmd decides). Restarted hypridle with the project config.
  When the shell lock exists (milestone e), switch lock_cmd to it WITHOUT relying on the exit code.
- Answered "what's missing for a pleasant experience" with a prioritized list (see reply).

### 2026-10-24 18:15–18:25 – hyprlock (themed) + root cause of "polkit/lock don't work"
- **Root cause found**: processes I start from my tool shell inherit `NoNewPrivs=1` → setuid helpers (unix_chkpwd for
  PAM password checks, polkit-agent-helper-1) can't work. The shell (polkit agent!) and hypridle (→ hyprlock) had been
  restarted by me from that shell. Fix: restart-shell.sh now starts the shell via `hyprctl dispatch exec_cmd`
  (child of Hyprland, NoNewPrivs=0); hypridle restarted the same way. Verified NoNewPrivs=0 for both.
  **Rule: never start long-running session processes directly from the tool shell; use hyprctl dispatch exec_cmd.**
- No /etc/pam.d/hyprlock (only in /etc/static: swaylock, gtklock, vlock, …) → hyprlock falls back to `su`.
  User: document, implement later → NIXOS_NOTES §5 (security.pam.services.hyprlock or programs.hyprlock.enable).
- New hypr/hyprlock.conf in COSMIC Dark colors (Fira Sans, amber pill input, blurred dimmed screenshot, time, date,
  user, now playing, battery; no external scripts). hypridle lock_cmd → `hyprlock -c ~/hypr-cosmic-shell/hypr/hyprlock.conf`.
  Not visually tested (would lock the user's screen) → user tests with SUPER CTRL L.

### 2026-10-24 18:20 – Portal root cause + user rule
- xdg-desktop-portal.service has `Requisite=graphical-session.target`; that target was inactive (plain Hyprland
  doesn't start it) → "Dependency failed" on every activation. xdph was running fine.
- Wrote hypr/session-target.sh (runtime unit in $XDG_RUNTIME_DIR BindsTo graphical-session.target, imports env,
  restarts portals). Ran it once: target + portals active, ScreenCast AvailableSourceTypes = 7. Portal works NOW.
- **User rule (very important): don't fix problems a display manager will fix.** → removed the autostart hook;
  script stays as a manual tool. NIXOS_NOTES §1 now: programs.hyprland.withUWSM = true (note: a greeter alone
  without UWSM doesn't start graphical-session.target either; told the user).

### 2026-10-24 18:25 – hyprlock per-scale + fancier; flake env for DM logins
- User: hyprlock works, but scaling is bad on 2880x1800 (scale 2), make it fancier.
  hyprlock sizes are physical px → new hypr/hyprlock-gen.py writes hypr/hyprlock.conf with one block per monitor
  (eDP-1 ×2, Dell ×1; fractional_scaling = 0). Design: big clock (bold hours, amber colon), date, frosted rounded card,
  amber avatar circle with initial, "Good evening, Mate" greeting, pill password field, bottom-left now playing,
  bottom-right battery (Material Symbols icons). User must lock (SUPER CTRL L) to see it.
- Found: shell.lua started system `qs` and autostart started system hypridle → outside a TTY start (start-hyprland.sh
  runs Hyprland inside the flake env) the shell would lose fonts/icons/QS_ICON_THEME/emoji file. New hypr/hcs-env
  wrapper (`nix run path:<root>#env -- "$@"`), HCS_ENV global in hyprland.lua; shell, hypridle, kdeconnect-indicator
  start through it; restart-shell.sh uses it. Restarted shell + hypridle via hyprctl dispatch (NoNewPrivs=0).
- Next (user's order): media control in the bar → night light control + status in the bar → quick settings panel.

### 2026-10-24 18:27–18:35 – System-wide install, part 1: dotfiles (user request)
- User: new branches in ~/dotfiles (git, symlinked into ~/.config by symlinkcmds.sh) and ~/Nix (git); implement
  dotfile changes first, then NixOS changes from the notes + what the flake provides.
- ~/dotfiles branch `hypr-cosmic-shell`, commit 19728c1 (`git commit -- config/hypr config/quickshell`, so the
  user's already-staged config/tlp/balanced.conf stays staged and uncommitted):
  - config/hypr: removed hyprland.conf + conf/*.conf, added hyprland.lua + conf/*.lua, hyprlock-gen.py (regenerated
    hyprlock.conf), hypridle.conf (plain `hyprlock`), scripts/restart-shell.sh (qs kill; hyprctl reload; dispatch qs).
    Removed obsolete scripts (hyprestart, swww, monitor_check, battery/media/network/whoami; nothing else used them).
    System variant differences vs project: HYPR = ~/.config/hypr, HCS_QS = "qs" (default config dir), shell started
    with plain `qs`, hypridle/kdeconnect-indicator plain, QS_ICON_THEME via hl.env, no polkit-gnome stop (NixOS does it),
    Config.qml without projectRoot/shellCmd. `--verify-config` ok; binds identical to project (95).
  - config/quickshell = project shell/ (2 files differ: Config.qml, shell.qml). Loads cleanly (tested with HCS_NO_NOTIFY=1).
  - Created symlink ~/.config/quickshell -> ~/dotfiles/config/quickshell (didn't exist before).
  - Current session unaffected (runs from the project paths).

### 2026-10-24 18:35–18:45 – System-wide install, part 2: NixOS (~/Nix branch hypr-cosmic-shell, 720714e)
- New system/matevono/hyprland-desktop.nix (imported in configuration.nix): programs.hyprland {enable, withUWSM}
  (session "Hyprland (uwsm-managed)" → graphical-session.target → portals work), security.pam.services.hyprlock,
  polkit-gnome user service ConditionEnvironment=!XDG_CURRENT_DESKTOP=Hyprland, xdg.portal.config.hyprland
  (hyprland;gtk, FileChooser cosmic, Secret kwallet), hardware.i2c + group, systemPackages (hypridle, hyprsunset,
  hyprshot, hyprpicker, grim, slurp, swappy, playerctl, brightnessctl, ddcutil, cliphist, wl-clipboard, wtype,
  libqalculate, libnotify, jq, curl, pavucontrol, networkmanagerapplet, gnome-calendar, kdeconnect-kde, pop-icon-theme),
  fonts (material-symbols, fira-sans, noto-fonts-color-emoji), sessionVariables.HCS_EMOJI_FILE.
  home/pkgs/default.nix: rofi, waybar, wlogout, awww commented out. quickshell stays in home/pkgs (pkgs-unstable).
- Verified: eval ok; `nix build .#nixosConfigurations.matevono.config.system.build.toplevel` ok (74 small drvs, 400 KiB);
  result has /etc/pam.d/hyprlock, hyprland-uwsm.desktop, polkit-gnome ConditionEnvironment, binaries, Pop icons;
  diff-closures: −rofi, −awww, −waybar deps, +hypr tools, +material-symbols. NOT switched (needs root; user does it).
- Dotfiles follow-up 11de04f: SUPER M / power menu "Log out" use `uwsm stop` when uwsm is active, else hl.dsp.exit().
  Synced Hypr.qml back to the project.
- User's ~/.config/xdg-desktop-portal/hyprland-portals.conf (untracked, not in dotfiles) overrides the system
  portal config → told user to delete it or add the Secret line.

### 2026-10-24 18:42–19:10 – Now on the system install; night light, quick settings, media card
- User rebuilt + logged in via cosmic-greeter → "Hyprland (uwsm-managed)". Verified: uwsm active,
  graphical-session.target + xdg-desktop-portal(-hyprland) active, HCS_EMOJI_FILE/QS_ICON_THEME set,
  shell = `qs` with ~/.config/quickshell → ~/dotfiles/config/quickshell.
  **From now on edit ~/dotfiles (hypr + quickshell) and ~/Nix directly; ~/hypr-cosmic-shell/shell + hypr are frozen.**
  Markdown docs stay here (PROGRESS.md, USER_GUIDE.md, NIXOS_NOTES.md); update them after every step.
- UWSM runs XDG autostart → polkit-gnome@autostart took the agent slot, nm-applet ran; pam_kwallet_init has
  X-systemd-skip → wallet stayed locked. ~/Nix bf622b4: HM xdg.configFile autostart overrides with NotShowIn=Hyprland
  for polkit-gnome + nm-applet; user service hyprland-kwallet-unlock (oneshot pam_kwallet_init, Hyprland only).
  Built (not switched). Applied by hand for this session: stopped both autostart units, ran pam_kwallet_init → wallet open.
- Night light (dotfiles e69d2ee): services/NightLight.qml (hyprctl hyprsunset profile/temperature/reset/identity,
  modes auto/on/off persisted across reloads, manual mode re-applied when the profile time changes, schedule parsed
  from hyprsunset.conf), modules/NightLightModule.qml. User: placed between clipboard and caffeine. IPC nightlight.
  Tested on → 4500 K, auto → 6000 (reset). "off" uses identity; temperature readback still says 4500 (can't verify).
- User: media must stay ONE bar button with the dropdown (my inline track + prev/play/next version reverted; it also
  caused a binding loop that flooded the log). Media controls now live in components/MediaCard.qml (quick settings
  + top of the notification center).
- Bar height 32 → 35 (user: "a bit taller, not by much"; 5431c3e).
- Quick settings (38677b7): quicksettings/QuickSettings.qml + components/QuickTile.qml; IPC quicksettings; SUPER comma.
  Verified via IPC + screenshot (layer hcs-quicksettings 400x572).
- **Bug: two shell instances** after an interrupted restart (old one survived `qs kill`, plus hung `qs ipc show`);
  second instance errored 'module "qs.bar" is not installed'. Killed all by PID; restart-shell.sh now waits/kills
  until no instance is left before starting one. Always use `timeout` on qs/hyprctl calls in tool commands.

### 2026-10-24 19:12–19:20 – Quick settings button, media card centering, bar icon size
- modules/QuickSettingsButton.qml ("tune", between bell and power) + services/QuickSettingsState.qml (shared open
  state; toggle ignored within 300 ms of a close so a button click closes instead of reopening).
- MediaCard: explicit AlignVCenter on cover/text/buttons, height 56+2·8, artist line hidden when empty
  (shows identity only if there's a title).
- Theme.barIconSize = 19 (user: bar icons ~1 pt bigger). Icon.qml walks parents for `barIcons: true`
  (set on the bar's left/center/right RowLayouts; window objects aren't Item parents). Tray uses barIconSize.
- Verified by screenshots. Committed in dotfiles.

### 2026-10-24 19:18–19:25 – Workspace circle + font weight fix
- Workspaces.qml: circle 26 px (Theme.workspaceCircle), cell = barHeight; number positioned with TextMetrics
  tightBoundingRect (centers the glyph, not the line box). Font size barFontSize-1, bold.
- Found: in the system session bold text rendered medium and regular rendered Light (system fonts include the
  `fira` package's many weights). Test: font.styleName picks correctly, font.weight doesn't. StyledText now sets
  font.styleName from font.weight imperatively (onFontChanged + guard; a binding was a loop). User: "looks good now".
- These edits ended up in the user's own dotfiles commit fd39519 "tlp" (together with config/tlp/balanced.conf),
  made while I was working. Left as is (no history rewrite).

### 2026-10-24 19:55–20:05 – Nextcloud calendar plan (not started) + GNOME Calendar crash
- User wants Nextcloud events in the calendar popup; asked for a plan only. Findings: no Nextcloud account on the
  machine (GOA: 2 Google accounts); EDS holds Google x2, Neptun webcal, local, birthdays; GNOME Calendar installed.
  Plan given: add the account once in GNOME Calendar/Online Accounts (EDS syncs it), a Python+PyGObject helper
  (EDS typelibs from the flake / ~/Nix) prints events as JSON, popup shows per-calendar dots + agenda + "Next up".
  Alternative: direct CalDAV via curl with the password in KWallet. Open: server URL, which calendars, tasks?
  Password must not be sent to the assistant. KWallet unlock (Nix bf622b4) still needs `nixos-rebuild switch`.
- User: `gnome-calendar` from fish aborts with GLib `g_time_zone_get_identifier: tz != NULL` ... SIGABRT.
  Reproduced exactly by launching with TZDIR unset or pointing at a wrong dir (e.g. /usr/share/zoneinfo);
  works with TZDIR=/etc/zoneinfo or the tzdata store path. NixOS has no /usr/share/zoneinfo, GLib finds zone files only
  via TZDIR. Same root as Quickshell's "Unable to determine system time zone" warning. /etc/localtime and timedated are
  fine (Europe/Budapest). My tool shell has TZDIR=/etc/zoneinfo and launches it fine, so the user's terminal
  environment differs; couldn't read it (permission). Waiting for `echo $TZDIR; env | grep -i ^TZ` from that terminal.
  Workaround for now: `TZDIR=/etc/zoneinfo gnome-calendar`.

### 2026-10-24 20:17–20:50 – Plain (non-UWSM) session: xdg-open + TZDIR + KWallet
- User moved to the GDM "Hyprland" (plain) session (edited configuration.nix: gdm on, cosmic-greeter off,
  gdm.enableKwallet; uncommitted, theirs) and asked whether UWSM is needed ("uwsm strips PAM variables").
- Findings: **UWSM is not needed.** PAM_KWALLET5_LOGIN was present under UWSM and in the plain session; what failed
  under UWSM was pam_kwallet_init never running (X-systemd-skip). TZDIR/LD_LIBRARY_PATH are removed from Hyprland's
  children by glibc secure-exec: NixOS `programs.hyprland` (nixos/modules/programs/wayland/hyprland.nix:93) installs
  Hyprland via security.wrappers.Hyprland with cap_sys_nice+ep. Reproduced: CapEff 0x800000 on Hyprland, child env has
  no TZDIR. Fix in dotfiles environment.lua: hl.env("TZDIR", "/etc/zoneinfo") (verified: new child has it).
- xdg-open failing: `xdg.portal.xdgOpenUsePortal = true` → needs org.freedesktop.portal.Desktop →
  xdg-desktop-portal.service has Requisite=graphical-session.target, inactive in a plain session ("Dependency failed").
  User had added dbus-update-activation-environment/import-environment to autostart (kept the intent).
- Fix: dotfiles config/hypr/scripts/session-target.sh (imports env, starts hyprland-session.target, or writes a runtime
  copy if the NixOS unit is missing; stop on hyprland.shutdown), hooked in autostart.lua. Applied to the running session:
  graphical-session.target + portals active, `xdg-open /tmp` opened COSMIC Files (closed it again).
  Nix: systemd.user.targets.hyprland-session in hyprland-desktop.nix (BindsTo graphical-session.target), built OK.
  Commits: dotfiles 0eaf668, Nix 4e0f055 (only hyprland-desktop.nix; user's configuration.nix change left alone).
- The running generation does NOT contain bf622b4/4e0f055 pieces (hyprland-kwallet-unlock.service missing) → rebuild
  needed. In the current session the wallet reads as open and unlocked; user's "apps don't see kwallet" not reproduced
  yet, need to know which app/what error.
- Tool shell note: /proc/<pid>/environ of user processes is unreadable for me; use a child of Hyprland
  (`hyprctl dispatch 'hl.dsp.exec_cmd("sh -c \"env > /tmp/x\"")'`) to see what apps get.

### 2026-10-24 21:00 – Back to the UWSM session (user decision)
- User: "uwsm removes my timezone, the normal doesn't; new plan: comment out what UWSM doesn't need in autostart and
  add the timezone to the environment." (My measurements: TZDIR was missing for Hyprland's children in BOTH session
  types until the hl.env line; stated that once, kept the plan.)
- dotfiles: autostart.lua: commented out the dbus-update-activation-environment / import-environment / portal restart
  lines (user's additions and the originals); environment.lua: TZDIR=/etc/zoneinfo enabled again, env-sync
  hyprland.start handler commented out. `--verify-config` ok; reload ok; a new child of Hyprland has TZDIR.
  session-target.sh stays in config/hypr/scripts (unused, hook already commented out by the user).
- Not tested under UWSM yet (current session is plain); applies at the next UWSM login.

### 2026-10-24 21:15 – nm-applet hidden under UWSM
- Cause: UWSM runs XDG autostart; nm-applet.desktop (NotShowIn=KDE;GNOME;COSMIC) comes from networkmanagerapplet,
  installed by the COSMIC NixOS module (in all retained generations since 49). bf622b4's nm-applet override is no
  longer in hyprland-desktop.nix (user's uncommitted edits).
- Done (user: "do the hide"): ~/.config/autostart/nm-applet.desktop with Hidden=true (local file, not in dotfiles);
  stopped app-nm\x2dapplet@autostart.service. Verified with a dry run of systemd-xdg-autostart-generator into /tmp:
  without the file 7 units incl. nm-applet, with it 6 and none for nm-applet. Takes effect at the next login too.

### 2026-10-24 21:18–21:40 – Calendar events in the clock popup (dotfiles cf8bdc2, Nix 609092b)
- User answers: Nextcloud URL not needed (added the account in GNOME Calendar themselves), show ALL calendars
  (Nextcloud + Google + Neptun), tasks with a due date count.
- Helper `config/quickshell/scripts/calendar-events.py FROM TO [--no-tasks] [--only=a,b]` (Python + PyGObject,
  EDataServer-1.2 / ECal-2.0 / ICalGLib-3.0): skips sources disabled or unchecked in GNOME Calendar,
  `generate_instances_sync` expands recurrences, tasks via `(due-in-time-range? ..) (not (is-completed?))`,
  prints JSON {calendars, events:[calendar,color,kind,title,start,end,allday,location,uid]} in local time.
  webcal colors "rgb(r,g,b)" converted to hex.
- **Gotcha:** `ECal.Client.connect_sync(src, kind, N)` waits up to N s for the backend to be *online*; every
  remote calendar cost the full N (15 s each), and N=0 means wait forever. `0xFFFFFFFF` ((guint32)-1) = don't wait,
  read EDS's cache → 0.05 s per calendar. Test: 63 events in October (mostly neptun.bme.hu, Personal, holidays).
- Needed typelibs: EDS, libical, glib, gobject-introspection (libxml2-2.0), libsoup_3, json-glib.
  ~/Nix `system/matevono/calendar-events.nix`: `hcs-calendar-events` wrapper (sets GI_TYPELIB_PATH, runs the
  script from ~/.config/quickshell/scripts, overridable with HCS_CALENDAR_SCRIPT), imported from
  hyprland-desktop.nix (only that import line committed; the user's own edits there stay uncommitted).
- services/CalendarEvents.qml: runs `hcs-calendar-events` for the viewed month ±1–2 weeks and today+31 days,
  on popup open, month change and every 15 min; tmp+mv into Quickshell cache `calendar-events.json`; byDay map
  (multi-day events on every day), nextUp (current or next timed event). Config: calendarHidden,
  calendarShowTasks, calendarRefreshMinutes.
- Clock.qml: "Next up" row (title, "in 25 min"/"Now · until"/date, location, calendar color dot), up to 3
  colored dots per day, click a day = select (amber ring), agenda for the selected day (color bar, time / All day /
  Due, title, location, max 6 rows + "+N more"), "offline" when the last run failed, click → gnome-calendar.
- Verified by screenshots with a cache seeded from the store-built wrapper (helper isn't on PATH until rebuild,
  so the popup says "offline" until then). Nix git: .git/objects/e6 was root-owned; user chowned it.

### 2026-10-24 21:38–21:42 – Weather popup details (dotfiles c8c9c7a)
- User: more info for today (rain, humidity, wind, ...). Weather.qml requests extra Open-Meteo fields: current
  relative_humidity_2m, wind_speed_10m/direction/gusts, pressure_msl; daily precipitation_sum,
  precipitation_probability_max, uv_index_max, sunrise, sunset (old caches parse fine, missing fields → 0).
- WeatherModule.qml: 3×2 tiles under the current temperature (Rain % + mm today, Humidity, Wind km/h with arrow +
  compass + gusts, UV + level, Pressure hPa, Sunrise + sunset), rain chance per day in the forecast rows,
  popup width 340. Verified by screenshot.

### 2026-10-24 21:42–21:48 – Power mode tile (tlpmodes.sh) + sudo NOPASSWD (dotfiles 3e887cf, Nix 8e05413)
- User: replace Airplane mode tile in Quick Settings with a toggle for `~/dotfiles/scripts/tlpmodes.sh` and add its
  commands to `NOPASSWD`.
- `services/PowerProfile.qml`: reads `/sys/firmware/acpi/platform_profile` (`low-power` / `balanced` / `performance`),
  cycles or sets mode via `~/dotfiles/scripts/tlpmodes.sh [low|balanced|power]`, exposes `powerprofile` IPC target
  (`cycle` / `saver` / `balanced` / `performance`).
- `quicksettings/QuickSettings.qml`: replaced Airplane mode tile with "Power mode" tile (shows current mode, amber in
  Performance, click cycles, chevron opens the battery popup).
- `modules/BatteryModule.qml`: added a 3-row Power mode selector (Power Saver, Balanced, Performance) to the battery popup.
- `~/Nix/system/matevono/configuration.nix`: `tlp` and `tee /sys/firmware/acpi/platform_profile` were already in
  `security.sudo.extraRules`; added `/run/current-system/sw/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`
  (used by `set_balanced` in `tlpmodes.sh`) and `/home/mate/dotfiles/scripts/tlpmodes.sh` with `NOPASSWD`.
  Verified `nix build` and UI via screenshots.

### 2026-10-24 21:51–22:07 – Quickshell app list in Launcher + Bar Settings app (dotfiles 0ff5012, 434d25c)
- User: add a Quickshell app list inside the launcher with a custom prefix key (like `=` calc and `:` emoji),
  populate it with existing Quickshell apps, and add a new app where bar items can be toggled on/off and reordered.
- `launcher/Launcher.qml`: prefix `!` (also `/` or `@`, or `qs ipc call launcher shell`) switches to `"shell"` mode,
  listing 17 built-in Quickshell apps/applets (Bar Settings, Quick Settings, Calendar & Events, Weather, Clipboard,
  Notifications, Audio & Volume, Network & Wi-Fi, Bluetooth, Display & Brightness, Media Player, Night Light,
  Battery & Power Mode, Tiling Layout, Color Picker, Emoji Picker, Next Wallpaper, Power Menu) with fuzzy search.
- **Gotcha fixed (434d25c):** calling `Qt.callLater(r.action)` inside the `LazyLoader`'s `PanelWindow` right after
  `root.open = false` canceled the callback because `LazyLoader` immediately destroyed the window; moved shell-app
  dispatch to a `Timer` on the outer `Scope` (`triggerShellApp`) so the target popup/window opens after the launcher
  unmaps. Also removed redundant `HyprlandFocusGrab` on the full-screen `BarSettingsWindow` overlay.
- `services/BarConfig.qml` + `bar/BarSettingsWindow.qml` + `bar/Bar.qml`: persistent bar layout in
  `~/.local/state/quickshell/.../bar-config.json` (`leftIds`, `centerIds`, `rightIds`, `enabledMap`). Bar Settings
  window has section filter tabs (`All`, `Left`, `Center`, `Right`), per-module toggle switch, `↑`/`↓` reorder buttons,
  clickable section badge (`Left` → `Center` → `Right`), and a `Reset` button.
- `components/Popup.qml`: if a bar module is hidden on the bar (`!anchorItem.visible`), its popup still works when
  opened from the Launcher's `!` list or keybinds and centers horizontally on screen.
  Verified both Launcher `!` mode and Bar Settings window via screenshots.

### 2026-10-24 22:09–22:35 – Quickshell apps open as real FloatingWindows from Launcher + Popup position fix (dotfiles 8940a94, 825642a, 544a64c)
- User: when opened from the launcher (`!`), apps should open in the center as normal actual windows (`FloatingWindow`)
  with floating window rules in Hyprland.
- `components/Popup.qml` + `services/Popups.qml` (`openWindow`) + `quicksettings/QuickSettings.qml` +
  `services/QuickSettingsState.qml` (`openWindow`) + `bar/BarSettingsWindow.qml`:
  - Clicking a bar icon still opens the layer-shell dropdown below the bar (`openDropdown`).
  - Launching from the Launcher (`!`) calls `Popups.openWindow(...)` / `QuickSettingsState.openWindow()`, reparenting
    the popup's content into a real XDG `FloatingWindow` (`class = "org.quickshell"`, `title = "HCS — <Name>"`),
    and `BarSettingsWindow` is also a `FloatingWindow` (`title = "HCS — Bar Settings"`).
- `config/hypr/conf/windowrules.lua`: added `float = true, center = true` rules matching `class = "^(org\\.quickshell|quickshell)$"`
  and `title = "^(HCS — ).*"`. Verified with `Hyprland --verify-config`, `hyprctl reload`, `hyprctl -j clients`, and screenshots.
- **Gotcha fixed (825642a, 544a64c):** on the first open of a bar dropdown, `visible: openDropdown` mapped the Wayland layer
  surface before `onOpenChanged` ran `reposition()`, while `anchorCenter` was still `0` and `root.width` was `0`,
  causing the popup to appear at `x = 4` (far left). Replaced `reposition()` with a reactive `anchorCenter` binding
  on the `RowLayout` + `Loader` + `BarButton` coordinates and used `popupWidth` (`contentWidth + 2 * padding`) in
  `margins.left`. Also in `Popups.qml` (544a64c): if a module is disabled on the bar (e.g. user hid `bluetooth` and
  `layout`), opening it from Quick Settings chevrons or IPC automatically uses `asWindow = true` (`FloatingWindow`).

### 2026-10-24 22:42–22:48 – Fix hyprlock (dark login box, "Sample Text", now-playing) & Media "Unknown title" (dotfiles a960e00)
- **Media ("Unknown title" when nothing is playing):** `kdeconnect.mpris_*` stays registered on D-Bus in `Paused` state with
  empty `trackTitle` and `trackArtist`. Filtered `Media.players` in `services/Media.qml` to require
  `p.isPlaying || Boolean(p.trackTitle)` (in addition to excluding `playerctld`), and updated `modules/MediaModule.qml`
  title fallback. Now the bar's Media popup shows `"Nothing is playing"` and `MediaCard` hides when nothing is loaded.
- **hyprlock fixes (`config/hypr/hyprlock-gen.py` → `hyprlock.conf`, `hypridle.conf`):**
  - Removed the dark `$card` (`rgba(27, 27, 27, 0.55)`) `shape` behind the avatar/greeting/password area that dimmed
    the main password entry region, and raised screenshot background `brightness` from `0.5` to `0.75`.
  - Fixed `"Sample Text"` ("test text") and missing now-playing audio at bottom-left: `playerctl metadata --format '{{artist}} – {{title}}'`
    contained `{{...}}`, which `hyprlang` rejected as an invalid math expression (`Invalid expression type: supported +, -, *, /`),
    causing `hyprlock` to ignore `text = ...` and fall back to its built-in default `"Sample Text"`. Replaced with a
    `playerctl -l` loop (no curly braces) that picks the active `Playing` player (or `Paused` player with a non-empty
    `xesam:title`, skipping idle `kdeconnect` and `playerctld`) and formats `artist – title` with Pango escaping.
  - Moved `playerctl pause-all;` in `hypridle.conf` from `lock_cmd` to `before_sleep_cmd` so locking the screen keeps
    audio playing (while suspending still pauses media), and restarted `hypridle` via `hyprctl dispatch` (`NoNewPrivs=0`).
  - Verified zero config errors with `WAYLAND_DISPLAY=nonexistent hyprlock -v` and verified Media popup via screenshot.

### 2026-10-24 22:51 – Stateful low-battery notifications (<20% normal, <10% critical)
- Updated `config/quickshell/osd/OsdTriggers.qml` (`checkBattery` with `warnedLow` / `warnedCritical` flags) so
  discharging below 20% sends one normal `"Battery low"` notification and dropping below 10% sends one critical
  `"Battery critical"` notification (also checked on unplug, and reset once charged back above each threshold).

### 2026-10-24 23:23 – Float desktop portal and screen-share picker windows
- Updated `config/hypr/conf/windowrules.lua` with `float = true, center = true, stay_focused = true` rules for
  `hyprland-share-picker` (`.hyprland-share-picker-wrapped`, `org.hyprland.xdg-desktop-portal-hyprland`, title
  `Select what to share` / `MainPicker`), `xdg-desktop-portal-*`, `org.freedesktop.impl.portal.desktop.*`, and
  `com.system76.CosmicPortal`. Verified with `Hyprland --verify-config` and reloaded with `hyprctl reload`.

### 2026-10-24 23:27–23:40 – Pop icon unification, horizontal workspaces + 4-finger swipe, KDE Plasma-style Overview
- **Icon pack unification (`Pop` + `BreezeX-Black` cursor):**
  - Set `icon_theme=Pop` in `~/.config/qt6ct/qt6ct.conf` and `~/.config/qt5ct/qt5ct.conf`.
  - Set `gtk-icon-theme-name=Pop` and `gtk-cursor-theme-name=BreezeX-Black` in `~/.config/gtk-3.0/settings.ini`,
    `~/.config/gtk-4.0/settings.ini`, and `gsettings` (`org.gnome.desktop.interface` `icon-theme` / `cursor-theme`),
    matching `QS_ICON_THEME=Pop` and `HYPRCURSOR_THEME=BreezeX-Black` in `config/hypr/conf/environment.lua`.
- **Horizontal workspaces & 4-finger horizontal gesture (`config/hypr/conf/niri.lua`):**
  - Changed workspace animation `style` from `"slidevert"` to `"slide"`.
  - Kept 3-finger horizontal swipe for `scroll_move` (scrolling the strip) and replaced 3/4-finger vertical workspace
    swipes with 4-finger horizontal workspace switching (`hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })`).
- **KDE Plasma-style Overview (`config/quickshell/bar/Overview.qml`, `services/Hypr.qml`, `conf/shell.lua`):**
  - Bound `SUPER + Tab` and `SUPER + W` (`qs ipc call overview toggle`), also accessible via right/middle-click on the
    bar's workspace dots and from the Launcher's `!` Quickshell apps list.
  - Top bar shows horizontal virtual desktop cards (`Desktop 1..N`) with live miniature `ScreencopyView` previews and a
    `+ New Desktop` button; middle has a search bar + `All Desktops` toggle; main area shows exposed live window
    thumbnails (`ScreencopyView`) with app icon, title, `<`/`>` move-to-desktop buttons, and `×` close button.
  - Added 4-finger vertical live gesture in `config/hypr/conf/niri.lua` (`hl.gesture({ fingers = 4, direction = "vertical", action = { start, update, finish } })`)
    streaming touchpad delta via `hl.dsp.event("hcs_overview:...")` on `socket2` to `services/Hypr.qml`, so 4-finger
    swipe up brings the Overview up following your fingers 1:1 and 4-finger swipe down brings it down with smooth
    `OutCubic` completion animation; also added window-level `Shortcut { sequences: ["Escape"] }` + focus restoration
    so `Escape` always closes the Overview immediately.
  - Verified with `Hyprland --verify-config`, `hyprctl reload`, and screenshot.

### 2026-10-24 23:51–23:58 – COSMIC Minimon-style modular system monitor (`SystemStats.qml`, `Stats.qml`)
- Upgraded `config/quickshell/services/SystemStats.qml`:
  - Reads CPU %, CPU package temperature, RAM / Swap / Shmem (`/proc/meminfo`), Network RX/TX (`/proc/net/dev`),
    Disk read/write (`/proc/diskstats` for `nvme*`/`sd*`), and Intel Arc GPU usage + frequency
    (`/sys/class/drm/card0/device/tile0/gt0/gtidle/idle_residency_ms` and `freq0/act_freq`).
  - Maintains 30-sample rolling history arrays for all 6 sensors and persists per-sensor bar display settings
    (`prefix: "none" | "icon" | "label"`, `text: bool`, `chart: "none" | "graph" | "ring"`, `interval`, `netInBits`,
    `monitorApp`) in `~/.local/state/quickshell/.../minimon-config.json`.
- Rewrote `config/quickshell/modules/Stats.qml` matching `~/hypr-cosmic-shell/minimon.png`:
  - Bar button displays enabled sensors with optional **Icon** or **Text label (`CPU`, `TEMP`, `MEM`, `NET`, `DISK`, `GPU`)**,
    value text (including stacked 2-line `↓ / ↑` network and `W / R` disk rates), and colored mini **sparkline graphs**
    (`SparkGraph`) or circular `RingGauge`s.
  - Dropdown popup (`qs ipc call bar toggle stats`) has the top `"System Monitor ↗"` pill button and a rounded card
    with divided rows (`General settings`, `CPU`, `CPU Temperature`, `Memory`, `Network`, `Disk`, `GPU`); clicking any
    row drills into a sub-page with a large live history chart, `"Prefix in bar"` (`Off` / `Icon` / `CPU`…),
    `"Show value in bar"` switch, and `"Chart in bar"` (`Off` / `Graph` / `Ring`) selector (plus one-click `"Quick style"`
    presets in `General settings` for `Graphs`, `Icons`, and `CPU/MEM`). Verified via screenshot.

### 2026-10-25 00:02–00:05 – Caffeine right-click interval dropdown & left-click toggle (`Idle.qml`, `Caffeine.qml`)
- Updated `config/quickshell/services/Idle.qml` and `config/quickshell/modules/Caffeine.qml`:
  - **Left click** on the bar's coffee icon: if Caffeine is currently on (either for a fixed interval or indefinitely),
    turns it **off**; if off, turns it **on indefinitely**.
  - **Right / middle click** (or the `>` chevron on the Caffeine tile in Quick Settings, or `!caffeine` in the Launcher):
    opens the Caffeine dropdown menu (`Indefinitely`, `15 minutes`, `30 minutes`, `1 hour`, `2 hours`, `4 hours`) with a
    live countdown timer that automatically turns Caffeine off when the interval expires. Verified via screenshot.

### 2026-10-25 00:08–00:15 – Cleanup of `~/hypr-cosmic-shell` & moving docs to `~/dotfiles/docs/`
- Moved `PROGRESS.md`, `USER_GUIDE.md`, `NIXOS_NOTES.md`, and `HANDOFF.md` from `~/hypr-cosmic-shell/` into `~/dotfiles/docs/`.
- Moved reference/scratch images (`minimon.png`, `kiro.txt`, and any scratch screenshots) to `/tmp/`, then restored `docs/kiro.txt` locally and added `kiro.txt` to `.gitignore`.
- Removed the obsolete `~/hypr-cosmic-shell` directory now that all work is tracked on branch `hypr-cosmic-shell` in `~/dotfiles` and `~/Nix`.
- Updated `HANDOFF.md`, `USER_GUIDE.md`, `NIXOS_NOTES.md`, and `PROGRESS.md` in `~/dotfiles/docs/` to reflect their new location and the rule that any temporary verification images must be stored in `/tmp` or `$XDG_RUNTIME_DIR`.

### 2026-10-25 00:21–00:31 – Built-in Capture & Screen Recorder + Hardware & Privacy Peripherals
- **Interactive Capture & Screen Recording Studio** (`services/Recorder.qml`, `bar/CaptureOverlay.qml`, `modules/RecorderIndicator.qml`, `scripts/capture.sh`):
  - Bound to **`SUPER + Print`** (`qs ipc call capture toggle`), Quick Settings footer (`photo_camera` / `videocam`), Display menu (`Record` tile), and Launcher (`!capture`, `!record`).
  - **Screenshot tab**: Region, Window, Full Screen, and Color Picker tiles; selectable action (`Copy`, `Save & Copy` to `~/Pictures/Screenshots/`, or `Annotate` in `swappy`) and delay timer (`Now`, `3s`, `5s`).
  - **Screen Record tab**: Record Full Screen, Region, or Window via `wf-recorder` / `wl-screenrec` (saved to `~/Videos/Recordings/`), with selectable audio source (`No Audio`, `System Audio`, `Microphone`).
  - **Bar Recording Indicator** (`RecorderIndicator.qml`): pulsing red dot + `REC MM:SS` pill appears on the bar while recording; left-click stops & saves (and copies file URI to clipboard), right-click opens the Capture Overlay.
  - Fixed stop signal handling in `scripts/capture.sh` and `services/Recorder.qml`: non-interactive `bash` did not forward `SIGINT` to foreground `wf-recorder`, so `capture.sh` now runs `wf-recorder`/`wl-screenrec` in background with PID tracking (`/tmp/hcs_recorder.pid`) + `trap` + `wait`, and `stopRecording()` runs `capture.sh stop` (`kill -INT <pid>` + `pkill -INT -x wf-recorder`) so every stop button stops & finalizes the MP4 immediately.
  - Fixed `slurp` hanging in `Record Region` when launched from Quickshell's `Process`: `Process` attaches an open pipe to `stdin`, which caused `slurp` (`!isatty(STDIN_FILENO)`) to block in `anon_pipe_read` waiting for EOF on `stdin` before ever creating its Wayland selection surface, wedging `Recorder.starting = true`. Redirected `< /dev/null` on `slurp`, `wf-recorder`, `wl-screenrec`, and `swappy`, and allowed `startRecording()` to cancel any in-flight `starting` state.
- **Privacy Indicator** (`services/Privacy.qml`, `modules/PrivacyIndicator.qml`, `scripts/hardware-status.py`):
  - Monitors PipeWire (`pw-dump` + `Pipewire.nodes`) and `/dev/video*` for active **Microphone**, **Camera**, and **Screen Share / Recording** streams.
  - Shows an amber privacy pill on the bar with `mic`, `videocam`, and/or `screen_share` icons whenever any app is capturing; clicking opens the Privacy popup listing each active app with quick `Mute Mic` and `Stop Recording` actions.
- **Removable USB / SD Automounter & Safe Eject** (`services/Storage.qml`, `modules/StorageModule.qml`):
  - Event-driven block device monitor (`udevadm monitor --subsystem-match=block`) + `lsblk -J`; automatically mounts newly connected removable USB/SD drives via `udisksctl mount` (toggleable in popup) and sends a desktop notification.
  - Shows a USB icon on the bar (and a Removable Drives card in Quick Settings) whenever a drive is connected, with one-click open in Files (`xdg-open`) and safe eject (`udisksctl unmount` + `udisksctl power-off`).
- **Bluetooth Battery Levels** (`services/Bt.qml`, `modules/BluetoothModule.qml`, `quicksettings/QuickSettings.qml`):
  - Combines `BluetoothDevice.battery` with `upower -d` fallback (`bt-battery`); displays battery percentage + icon on connected device rows in the Bluetooth popup, on the bar button, and in the Quick Settings Bluetooth tile subtitle.

### 2026-10-25 00:36–00:39 – Notification toast fade-out & click-to-focus app activation
- Updated `config/quickshell/services/Notifs.qml`, `config/quickshell/notifications/Toasts.qml`, `config/quickshell/components/NotificationCard.qml`, and `config/hypr/conf/looks.lua`:
  - Normalized toast duration in `Notifs.timeoutFor(n)` to **4.5 s** by default (converting millisecond `expireTimeout` values > 100 and clamping to 3–6 s, 10 s for critical) so toasts never get stuck on screen when apps pass millisecond timeouts.
  - Added smooth `180 ms` fade-in and `360 ms` fade-out animations in `Toasts.qml` (canceling fade-out if hovered).
  - Enabled `misc.focus_on_activate = true` in `config/hypr/conf/looks.lua` so XDG activation requests from apps (Discord, Brave, Telegram, Slack, etc.) when clicking a notification immediately focus the window and switch to its workspace.
  - Enhanced `Notifs.activate(n)` and `Notifs.invokeAction(n, action)` (used by both toasts and the Notification Center) to close the Notification Center popup, invoke the notification's `default` D-Bus action (so the app navigates to the exact chat/tab/item), focus the matching Hyprland window by `desktopEntry` / `appName` / `appIcon` if not already activated, or open any local file path referenced in the notification via `xdg-open`.

---

## Decisions (defaults, user may override)

1. **Testing** (changed 16:22 by user): **no nested Hyprland.** The user will start a real Hyprland
   session themselves from a TTY with `./start-hyprland.sh`. I test with `run.sh` on COSMIC
   (layer-shell works; Hyprland modules stay empty) and `Hyprland --verify-config`.
   Anything that needs a live Hyprland → stop and tell the user what to run.
2. **Keybinds**: copy all user binds verbatim, including the broken ones
   (`$altMod`/`$shiftMod` undefined; `cfish_greetingliphist` typo in SUPER SHIFT C). Add a comment flagging them; do not fix unless asked.
3. **Wallpaper**: Quickshell background layer (`WlrLayer.Background`) rotating `~/Pictures/BingWallpaper`
   every 300 s with crossfade, zoom/crop (matches COSMIC Background settings). Replaces `swww.sh`/awww in the copy only.
4. **Font**: Fira Sans for UI (COSMIC's "Noto Sans Adlam" looks accidental), JetBrainsMono Nerd Font for mono/fallback icons,
   Material Symbols Rounded for icons. All supplied by the flake.
5. **Weather**: Open-Meteo at Tempest's coordinates (Gyömrő 47.42733, 19.40133), Celsius, 15 min refresh,
   cached to Quickshell cache dir, IP-geolocation fallback, fail silently offline.
6. **Monitors**: bar on every screen (`Variants` over `Quickshell.screens`); workspaces shown per monitor.
7. **Binds** (changed 17:05 by user: replace old apps on their original keys):
   SUPER Space launcher, SUPER SHIFT C clipboard, SUPER L power menu, SUPER SHIFT R restart shell + reload.
   New keys only for new features: SUPER N notifications, SUPER CTRL L lock, SUPER comma quick settings.
   Implemented via `qs -p <root>/shell ipc call <target> <fn>` (IpcHandler).
8. **Config copy changes**: in `hypr/conf/autostart.conf` copy, replace `waybar` and `dunst` with the shell
   (only one notification daemon can own the D-Bus name). All `source =` paths point at the copy.
9. **Lock screen**: native `WlSessionLock` + `PamContext` (milestone e). hypridle copy calls the shell's lock via IPC.
10. **nixpkgs pin**: same revision as the running system (`fe13242`, NixOS 26.11) so Mesa/GPU libs match.

---

## Findings

### Hyprland config (`~/.config/hypr`, never write here)
- Monitors: `eDP-1,2880x1800@120,0x0,2,vrr,1`; `desc:Dell Inc. DELL U2412M 0FFXD4152LWL,1920x1200@59.9500,320x-1200,1,vrr,0`; `,preferred,auto,auto`.
- Touchpad device `ftcs0038:00-2808:0105-touchpad` natural_scroll, sensitivity 0.03.
- Input: `kb_layout=hu`, `kb_options=fkeys:basic_13-24`, sensitivity -0.4, follow_mouse 1.
- Looks: gaps 3/7, border 2, `col.active_border = rgba(cb581aee) rgba(ffffffee) 45deg`, rounding 5,
  inactive_opacity 0.75, blur 3/1, dwindle (pseudotile, preserve_split), allow_tearing, vrr 2.
- exec-once: waybar, dunst, hypridle, `wl-paste --type text|image --watch cliphist store`, xembedsniproxy,
  dbus-update-activation-environment, systemctl import-environment.
- exec: hyprsunset, `~/.config/hypr/scripts/swww.sh` (awww-daemon, BingWallpaper, 7 min).
- hypridle: lock at 245 s (`loginctl lock-session` → hyprlock), dpms off 250 s, suspend 600 s.
- Keybinds (keep all):
  - SUPER: C kitty, Q killactive, M exit, E thunar, V togglefloating, F fullscreen,
    Space (bindr) rofi drun, P pseudo, J togglesplit, L wlogout, B brave, S special:magic,
    arrows movefocus, 1–0 workspace 1–10, mouse_down/up workspace e±1,
    mouse:272 movewindow, mouse:273 resizewindow
  - SUPER SHIFT: R hyprestart.sh, 1–0 movetoworkspace, S movetoworkspace special:magic,
    C cliphist via rofi (typo), F23 `wtype -k Control_R`
  - SUPER CTRL mouse:272 resizewindow
  - Print hyprshot output; `$altMod` Print window; `$shiftMod` Print region; `$altMod` P play-pause (vars undefined)
  - XF86 volume (binde, wpctl, limit 1.5), mute, play, next, prev, F11 play-pause, brightness (brightnessctl ±10%)
  - bindl lid on → monitor_check.sh, lid off → re-enable eDP-1

### COSMIC theme (Dark, `~/.config/cosmic/com.system76.CosmicTheme.Dark/v2/`)
- accent `#FFAD00` hover `#E09E14` pressed `#8A610B` on `#000000`
- background `#1B1B1B` on `#EEEEEE` divider `#454545`; transparent_background `#1B1B1BC8`
- background.component `#2E2E2E` / hover `#434343` / pressed `#585858` / divider `#FFFFFF33` / border `#BEBEBE`
- primary `#272727` (component `#363636`, hover `#4A4A4A`), divider `#525252`
- secondary `#343434` (component `#3B3B3B`, hover `#4F4F4F`), divider `#5C5C5C`
- button `#9E9E9E40` hover `#63636366`; icon_button on `#BEBEBE` hover `#63636333` pressed `#16161680`
- text_button on `#FFAD00`
- destructive `#FFA09A`, success `#5EDB8C`, warning `#FFA37D`
- shade rgba(0,0,0,0.32)
- spacing: none 0, xxxs 4, xxs 8, xs 12, s 16, m 24, l 32, xl 48, xxl 64, xxxl 128
- corner radii: no file → COSMIC defaults 0, 4, 8, 16, 32, 160
- gaps (0, 3); frosted Low2; font "Noto Sans Adlam"; icon theme "Pop"
- Light accent is `#00525A` (not used, dark-only shell for now)
- Panel: Top, anchor_gap true, border_radius 160, margin 4, opacity 0.66, size XS, output All,
  exclusive zone, layer Top. Left wing: workspaces, clipboard, caffeine, minimon.
  Center: Tempest weather, time. Right: status area, ext-monitor brightness, tiling, audio,
  bluetooth, network, battery, notifications, power.
- Time applet: military_time true, show_weekday true, first_day_of_week 0 (Sunday).
- Background: `~/Pictures/BingWallpaper` (114 jpgs), rotation 300 s, Zoom, Random.

### System facts
- User `mate`, home `/home/mate`. Currently in a **COSMIC** session (`WAYLAND_DISPLAY=wayland-1`).
- NixOS 26.11.20261015.fe13242; nix 2.34.9 with flakes enabled. System config not in `/etc/nixos` (location unknown; `~/dotfiles` only has ly + pam).
- Hyprland **not installed** (no hyprctl / Hyprland / hypridle / hyprsunset). Installed: hyprlock, awww, cliphist, rofi, waybar, quickshell 0.3.2, wpctl, playerctl, nmcli, bluetoothctl, upower.
- nixpkgs: quickshell 0.3.2, hyprland 0.56.2, material-symbols 4.0.0-unstable-2026-10-02.
- Services: upower, bluetooth, NetworkManager active; **power-profiles-daemon inactive** (→ NIXOS_NOTES).
- Hardware: Intel Core Ultra 5 125H, Arc iGPU; BAT0, ADP1; backlight `intel_backlight`;
  CPU temp hwmon `coretemp` label "Package id 0" (`temp1_input`, look up by name, hwmon number can change).
- Fonts installed: FiraCode Nerd Font, Fira Sans, JetBrainsMono.

---

## Repository layout (`~/dotfiles` branch `hypr-cosmic-shell`)

```
~/dotfiles/
  config/hypr/hyprland.lua, config/hypr/conf/*.lua
  config/hypr/hypridle.conf, config/hypr/hyprsunset.conf, config/hypr/hyprlock.conf, config/hypr/hyprlock-gen.py
  config/quickshell/shell.qml, config/quickshell/Theme.qml, config/quickshell/Config.qml
  config/quickshell/bar/  modules/  services/  components/  launcher/  notifications/  osd/  quicksettings/  polkit/  lock/
  docs/PROGRESS.md  docs/USER_GUIDE.md  docs/NIXOS_NOTES.md  docs/HANDOFF.md
```

## Next steps
0. Calendar: after the rebuild, check `hcs-calendar-events` is on PATH and the popup's "offline" label is gone;
   ask whether to hide duplicates (both "Neptun" webcal and "neptun.bme.hu" exist) via `Config.calendarHidden`.
1. User: `sudo nixos-rebuild switch --flake ~/Nix#matevono` for autostart overrides, KWallet unlock, `hcs-calendar-events`, and TLP NOPASSWD rules.
2. Remaining optional ideas: Alt+Tab switcher, screen recording button.
3. Work in `~/dotfiles` + `~/Nix` (branch `hypr-cosmic-shell`), commit per feature, keep temporary screenshots in `/tmp`, and update the `.md` files in `~/dotfiles/docs/` every step.
