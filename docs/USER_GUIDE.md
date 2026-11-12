# Hyprland COSMIC Shell & Dotfiles: User Guide

A Wayland desktop environment combining **Hyprland** (Lua configuration with a scrolling layout) and **Quickshell** (a COSMIC Dark desktop shell), plus shell, terminal, editor, and Qt theming configs.

*(Historical note: Niri was used for a short time before switching to Hyprland's scrolling layout.)*

Configuration lives in `~/dotfiles/` and is symlinked into `~/.config/` and `~/.scripts/` by [`link.sh`](file:///home/mate/dotfiles/link.sh):
- Hyprland: [`config/hypr/`](file:///home/mate/dotfiles/config/hypr) -> `~/.config/hypr/`
- Desktop Shell: [`config/quickshell/`](file:///home/mate/dotfiles/config/quickshell) -> `~/.config/quickshell/`
- Scripts: [`scripts/`](file:///home/mate/dotfiles/scripts) -> `~/.scripts/`

---

## 1. Architecture Overview

```text
                       ┌───────────────────────────────────────────────┐
                       │          Hyprland Compositor (Lua API)        │
                       │  - Scrolling layout & column width rules      │
                       │  - Touchpad gestures & dynamic SUPER+F toggle │
                       │  - Window/layer rules & DPMS cursor recovery  │
                       └───────┬───────────────────────────────┬───────┘
                               │                               │
                Layer Shell IPC│                  Socket2 Events
                               ▼                               ▼
       ┌───────────────────────────────────────────────────────────────┐
       │                 Quickshell Desktop Shell (qs)                 │
       │  - Top Panel (Bar): 22 modular, reorderable widgets           │
       │  - Launcher (SUPER+Space) & Overview (SUPER+Tab)              │
       │  - Quick Settings (SUPER+,) & Notifications / OSD Toasts      │
       │  - Capture Studio (SUPER+Print) & Polkit Prompt               │
       │  - Multi-mode Background (slideshows, images, shaders, loops) │
       └───────────────────────────────────────────────────────────────┘
                               │
                  Separate systemd unit (hcs-lock.service)
                               ▼
       ┌───────────────────────────────────────────────────────────────┐
       │         Quickshell Lock Screen (lock.qml via lock.sh)         │
       │  - Dual parallel PAM: instant password + Howdy IR face scan   │
       │  - Blurred desktop wallpaper, clock, MPRIS pause, Suspend     │
       └───────────────────────────────────────────────────────────────┘
```

The shell is built with **Qt 6 / QML** via Quickshell and styled after **COSMIC Dark** ([`Theme.qml`](file:///home/mate/dotfiles/config/quickshell/Theme.qml)), integrating with NetworkManager, PipeWire, BlueZ, UPower, TLP, `hyprsunset`, and Evolution Data Server (EDS).

---

## 2. Managing the Environment & IPC

### Quick Commands

| Action | Command / Shortcut | Description |
|---|---|---|
| **Restart Shell + Reload Hyprland** | `SUPER + SHIFT + R` | Cleanly restarts the main Quickshell process and runs `hyprctl reload`. |
| **Restart Shell Only** | `~/.config/hypr/scripts/restart-shell.sh` | Restarts the main shell (`shell.qml`) without touching an active lock screen (`lock.qml`). |
| **View Shell Logs** | `qs log` | Displays live Quickshell output and runtime QML errors. |
| **Check Hyprland Config Errors** | `hyprctl configerrors` | Validates Hyprland Lua syntax. |
| **Hot Reload** | Save any existing file in `config/quickshell/` | Quickshell automatically reloads modified `.qml` files (new folders require `restart-shell.sh`). |
| **Lock Session** | `loginctl lock-session` or `~/.config/hypr/scripts/lock.sh` | Launches or signals `hcs-lock.service` (`qs -p ~/.config/quickshell/lock.qml`). |

### Shell IPC Reference

Invoke `IpcHandler` targets on the main shell with `qs ipc call <target> <method> [args]`:

- **Bar popups**: `bar toggle <name>` / `bar openWindow <name>` / `bar back` / `bar close` (e.g. `volume`, `network`, `bluetooth`, `clipboard`, `weather`, `calendar`, `background`, `display`, `layout`, `media`, `battery`, `stats`, `nightlight`, `caffeine`, `storage`, `privacy`, `notifications`, `power`)
- **Overlays & panels**: `launcher toggle|emoji|shell|open|close`, `overview toggle|open|close`, `quicksettings toggle|open|close`, `capture toggle|open|recordMenu|close|shot <mode>`
- **Shortcut targets**: `clipboard toggle`, `notifications toggle`, `power toggle`, `picker color`
- **System & appearance**: `wallpaper next|prev|togglePause|setMode <m>|setFolder <p>|setImage <p>|setScene <id>|setPalette <id>|setSolidColor <hex>|screenUrls`, `nightlight toggle|auto|on|off`, `powerprofile cycle|saver|balanced|performance`, `kbd cycle|toggle|set <level>`, `workspaces focus <selector>`
- **Settings windows**: `barsettings toggle|open|close|reset`, `opacity toggle|open|close|reset`
- **Weather**: `weather refresh`, `weather open [settings|location|bar|popup|units]`

Lock screen IPC (runs on the separate `lock.qml` instance):

```bash
qs -p ~/.config/quickshell/lock.qml ipc call lock <lock|lockForSleep|wakeFromSleep|isLocked|status>
```

---

## 3. Keybindings Reference

`SUPER` is the Windows / Super key.

### Applications & Desktop Shell

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Space` | **App Launcher** | Search apps, evaluate math (`=`), run commands (`>`), search emojis (`:`), or open shell applets (`!`). |
| `SUPER + Tab` / `SUPER + W` | **Overview** | Niri-style vertical stack of workspaces with horizontal window strips, live previews, search filter, drag-and-drop reordering across/inside workspaces, and close/move controls. |
| `SUPER + ,` (Comma) | **Quick Settings** | Control center dropdown with quick tiles, volume/brightness sliders, and media controls. |
| `SUPER + N` | **Notification Center** | Notification history, Do Not Disturb toggle, and media playback card. |
| `SUPER + .` (Period) | **Emoji Picker** | Opens the launcher directly in `:` emoji mode; Enter types and copies the emoji. |
| `SUPER + SHIFT + C` | **Clipboard History** | `cliphist` manager with search and image previews. |
| `SUPER + SHIFT + P` | **Color Picker** | `hyprpicker` eyedropper; copies `#RRGGBB` hex to clipboard and shows an OSD preview. |
| `SUPER + Print` | **Capture Studio** | Interactive screenshot and screen recording overlay. |
| `SUPER + L` | **Lock Screen** | Locks the session via `loginctl lock-session`. |
| `SUPER + CTRL + L` | **Power Menu** | Session controls: Lock, Suspend, Log out, Restart, Shut down (keyboard navigable). |
| `SUPER + SHIFT + R` | **Restart Shell** | Restarts Quickshell and reloads Hyprland config. |
| `SUPER + C` | Terminal | Launches `kitty`. |
| `SUPER + E` | File Manager | Launches `nautilus`. |
| `SUPER + B` | Web Browser | Launches `brave-origin`. |
| `SUPER + SHIFT + F23` | Right Control | Sends `Control_R` via `wtype`. |

### Windows & Workspaces

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Q` | Close Window | Closes the active window. |
| `SUPER + V` | Toggle Floating | Switches window between floating and tiled. |
| `SUPER + M` | Exit Session | Stops the UWSM session cleanly (or exits Hyprland directly). |
| `SUPER + P` | Pseudotile | Toggles pseudotiling (dwindle layout). |
| `SUPER + J` | Toggle Split | Toggles split orientation (dwindle layout). |
| `SUPER + 1 … 0` | Switch Workspace | Switches to workspace 1 through 10. |
| `SUPER + SHIFT + 1 … 0` | Move to Workspace | Moves the active window to workspace 1 through 10 and follows it. |
| `SUPER + S` | Toggle Scratchpad | Shows or hides the `special:magic` scratchpad workspace. |
| `SUPER + SHIFT + S` | Move to Scratchpad | Moves the active window to `special:magic` and follows it. |
| `SUPER + Left Drag` | Move Window | Drags window with the mouse. |
| `SUPER + Right Drag` / `SUPER + CTRL + Left Drag` | Resize Window | Resizes window with the mouse. |

### Scrolling Layout (`config/hypr/conf/scrolling.lua`)

Hyprland uses the built-in `scrolling` layout by default: windows open as columns on a horizontal strip, with workspaces stacked vertically per monitor.

| Keybind / Gesture | Action | Description |
|---|---|---|
| `SUPER + F` | **Smart Width Toggle** | Toggles between `1.0` (full width) and the window's previous width (defaults to `0.5` if opened full-width; falls back to maximize when floating or in another layout). |
| `SUPER + SHIFT + F` | **True Fullscreen** | Toggles exclusive fullscreen mode. |
| `SUPER + R` / `SUPER + CTRL + R` | Cycle Widths | Cycles preset column widths (`0.333`, `0.5`, `0.667`, `1.0`) forward / backward. |
| `SUPER + ü` / `SUPER + ó` | Adjust Width (±10%) | Shrinks (`-0.1`) or expands (`+0.1`) the focused column width. |
| `SUPER + ő` / `SUPER + ú` | Consume / Expel | Pulls the previous/next window into the current column or expels it. |
| `SUPER + CTRL + C` | Center Column | Centers the focused column on screen. |
| `SUPER + ← / →` | Focus Column | Moves focus left/right across columns (and to the adjacent monitor at strip edges). |
| `SUPER + ↑ / ↓` | Focus in Column | Moves focus up/down within a stacked column. |
| `SUPER + CTRL + ← / →` | Swap Column | Swaps the focused column left/right. |
| `SUPER + CTRL + ↑ / ↓` | Move in Column | Moves the active window up/down inside its column. |
| `SUPER + Page Down / Up`<br>`SUPER + U / I` | Next / Prev Workspace | Moves to the next or previous workspace on this monitor (including empty trailing workspace). |
| `SUPER + CTRL + Page Down / Up`<br>`SUPER + CTRL + U / I` | Move to Workspace | Moves the active window to the next or previous workspace and follows it. |
| `SUPER + SHIFT + Arrows` | Focus Monitor | Moves focus to the monitor in that direction. |
| `SUPER + SHIFT + CTRL + Arrows` | Move to Monitor | Moves the active window to the monitor in that direction and follows it. |
| `SUPER + Mouse Scroll` | Scroll Columns | Focuses column left/right. |
| `SUPER + SHIFT + Mouse Scroll` | Switch Workspace | Cycles existing workspaces (`e+1` / `e-1`). |
| **3-Finger Horizontal Swipe** | Strip Scroll | Smooth 1:1 horizontal scrolling across columns (snaps to column edges). |
| **3-Finger Vertical Swipe** | Workspace Switch | Switches vertical workspaces (creates a new one past the end). |
| **4-Finger Vertical Swipe** | Live Overview | Pulls the Overview open or closed 1:1 with finger movement. |

**Automatic Column Widths**: Terminals (`kitty`, `CosmicTerm`, `foot`, `Alacritty`, `wezterm`, `gnome-console`) and file managers (`thunar`, `nautilus`, `CosmicFiles`, `dolphin`) open at `0.5` width; all other apps open at `1.0`. Self-maximize events are suppressed so apps respect column geometry.

### Screenshots, Hardware Keys & Lid Switch

| Key / Event | Action |
|---|---|
| `Print` | Screenshot focused output to clipboard (`hyprshot`). |
| `ALT + Print` | Screenshot active window to clipboard (`hyprshot`). |
| `SHIFT + Print` | Screenshot selected region to clipboard (`hyprshot`). |
| `XF86AudioRaiseVolume` / `LowerVolume` | Adjusts output volume by ±5% (capped at 150%) + OSD toast. |
| `XF86AudioMute` | Toggles output mute + OSD toast. |
| `XF86AudioMicMute` | Toggles microphone mute + OSD toast. |
| `XF86AudioPlay`, `CTRL + ALT + Tab` (F11 overview key), `ALT + P` | Toggles media playback (`playerctl play-pause`). |
| `XF86AudioNext` / `Prev` | Skips track forward / backward. |
| `XF86MonBrightnessUp` / `Down` | Adjusts laptop screen brightness by ±10% + OSD toast. |
| Laptop Lid Close | With 1 monitor: suspends system. With external monitor: disables `eDP-1`. |
| Laptop Lid Open | Re-enables `eDP-1` (`2880x1800@120`, scale 2, VRR). |

---

## 4. Top Panel & Modular Widgets

The top panel ([`Bar.qml`](file:///home/mate/dotfiles/config/quickshell/bar/Bar.qml)) hosts 22 modular widgets configurable via **Bar Settings**:

| Widget | Left Click | Right / Middle Click | Details |
|---|---|---|---|
| **Workspaces** | Focus workspace | Right/Middle: Toggle Overview. Scroll: cycle workspaces | Shows active workspaces per monitor with optically centered digits. |
| **Clipboard** | Open clipboard history | — | Search `cliphist` text/image entries, copy with Enter, or wipe history. |
| **Night Light** | Open Night Light menu | Right/Middle: Toggle on/off | Warmth slider (`2500–6000 K`) and automatic schedule (`20:00–08:30`) via `hyprsunset`. |
| **Caffeine** | Toggle keep-awake on/off | Right/Middle: Preset timer menu | Wayland `IdleInhibitor` with `Indefinitely`, `15m`, `30m`, `1h`, `2h`, `4h` timers and countdown. |
| **System Stats (Minimon)** | Open sensor popup | Right/Middle: Open system monitor | Live sparklines/rings/values for CPU, CPU Temp, Memory, Network, Disk, and Intel Arc GPU. |
| **Weather** | Open modular forecast | Right: Weather settings. Middle: Refresh forecast | Current summary, 12h/24h hourly timeline, configurable detail tiles, 3–10 day forecast, location search/IP auto-locate, and unit settings (HungaroMet 10-min stations + Open-Meteo hybrid, or Open-Meteo exclusively). |
| **Clock & Calendar** | Open calendar & agenda | — | Month calendar synced with Evolution Data Server (GNOME Calendar / Nextcloud / Google / Neptun) + tasks. |
| **Screen Recorder** | Stop & save recording | Right/Middle: Open Capture Studio | Shown only while recording (`REC MM:SS`); saves to `~/Videos/Recordings/`. |
| **Privacy Indicator** | Open active capture list | — | Appears when mic, webcam, or screen capture is active, with quick mute/stop actions. |
| **Removable Drives** | Open drive menu | — | Appears when USB/SD media is present; supports automount, open in Files, and safe eject (`udisksctl`). |
| **Background** | Open Background settings | Right: Next wallpaper / toggle anim pause. Middle: Pause/Resume | Switch between Folder slideshows, Single images/GIFs, Live GPU shader scenes or GIF/video loops, and Solid backdrops, plus blur/dim/fit effects. |
| **System Tray** | Focus / activate item | Right: App context menu | Hosts StatusNotifierItem (SNI) tray icons. |
| **Display & Brightness** | Open display menu | Scroll: adjust brightness | Laptop + external DDC/CI brightness, keyboard backlight (`Off`/`Low`/`High`), `60/120 Hz` toggle, and quick capture actions. |
| **Tiling Layout** | Toggle `scrolling` ↔ `dwindle` | Right: Layout list & actions | Switch between `dwindle`, `master`, `scrolling`, and `monocle`, plus column/split actions. |
| **Media Player** | Open media popup | Right/Middle: Play/Pause | Album art, title/artist, seek bar, volume, and player switcher (MPRIS). |
| **Volume** | Open audio mixer | Middle: Toggle mute. Scroll: volume | Output/input device selector, per-app PipeWire sliders, and `pavucontrol` shortcut. |
| **Bluetooth** | Open Bluetooth menu | Middle: Toggle Bluetooth | Paired devices (with battery % and 2-click right-click forget) plus collapsible scan list. |
| **Network & VPN** | Open network menu | — | Ethernet status, NetworkManager VPN/WireGuard manager (with inline password prompt), and Wi-Fi list. |
| **Battery** | Open battery menu | — | Charge/health status, TLP power mode selector (`Power Saver` / `Balanced` / `Performance`), `60/120 Hz` toggle, and session-only blur toggle. |
| **Notifications** | Open notification center | Middle: Toggle Do Not Disturb | Notification history, Clear All, DND switch, and media card. |
| **Quick Settings** | Open Quick Settings | — | Equivalent to `SUPER + ,`. |
| **Power Menu** | Open power menu | — | Equivalent to `SUPER + CTRL + L` (two-click confirm for Log out / Restart / Shut down). |

---

## 5. Built-In Shell Apps & Features

- **Widget Back Navigation (`Escape` & `←`)**: Drilling down from **Quick Settings** into a bar widget or **Capture Studio**, from **Display** into **Background** or **Capture Studio**, from **Bar Settings** into **Opacity & Transparency**, or into sub-pages/prompts (such as **Background** effects, **System Stats** sensor views, **Weather** settings, inline **Network** password prompts, or **Power** confirmations) pushes onto the shell navigation history (`WidgetHistory.qml`). Pressing `Escape` or clicking the header `←` button steps back to the previous view/widget before closing; clicking outside or completing an action dismisses everything immediately.
- **Bar Settings** (`!bar` or `qs ipc call barsettings toggle`): Toggle any of the 22 widgets, reorder within sections (`↑` / `↓`), move between Left/Center/Right, or reset defaults (`bar-config.json`).
- **Weather Settings** (Gear icon, right-click bar widget, or `qs ipc call weather open settings`): Toggle between **HungaroMet + Open-Meteo** (10-minute Hungarian station measurements merged with Open-Meteo forecasts, falling back automatically abroad) and **Open-Meteo only**; toggle and reorder bar pills (`icon`, `temp`, `condition`, `feelsLike`, `rain`, `wind`, `humidity`, `highLow`, `location`), popup sections, and 10 detail tiles; configure IP auto-locate, Open-Meteo city search, saved locations, custom coordinates, units, and refresh interval (`weather-config.json`).
- **Opacity & Transparency** (`!opacity` or `qs ipc call opacity toggle`): Independent opacity sliders for Widgets (`96%`), Bar (`66%`), Notifications (`96%`), and OSD Toast (`96%`), with **Default**, **Frosted Glass**, **Clear**, and **Solid** presets (`opacity-config.json`).
- **App Launcher** (`SUPER + Space`):
  - Default: fuzzy app search weighted by launch frequency (`launcher-usage.json`).
  - `=expr` (or plain arithmetic): evaluates via `qalc`; Enter copies result.
  - `>cmd`: executes a shell command (`Shift + Enter` runs it inside `kitty`).
  - `:name` (or `SUPER + .`): searches Unicode emojis; Enter copies and types via `wtype`, `Shift + Enter` copies only.
  - `!name` (also `/name`, `@name`): launches Quickshell panels and tools as centered floating windows (`!bar`, `!background`, `!opacity`, `!overview`, `!capture`, `!record`, `!lock`, `!wallpaper`, `!colorpicker`, `!power`, etc.).
- **Capture Studio** (`SUPER + Print`): Region, window, full-screen, and color picker screenshots (`Copy`, `Save & Copy` to `~/Pictures/Screenshots/`, or `Annotate` with `swappy`, with `0s`/`3s`/`5s` delay), plus screen recording (`wf-recorder` / `wl-screenrec` to `~/Videos/Recordings/` with optional system or mic audio).
- **Lock Screen** (`SUPER + L` or idle timeout): Runs in an isolated Quickshell process (`lock.qml` via `lock.sh`). Runs password (`qs-lock`) and Howdy IR (`qs-lock-face`) PAM checks in parallel so typing a password unlocks immediately even while Howdy is scanning, automatically hides face UI when Howdy/face models are absent, avoids pre-suspend Howdy unlocks via `lockForSleep`, shows pause-only MPRIS media controls, and offers a bottom-right `Suspend` pill.
- **Background & Wallpaper Engine** ([`BackgroundModule.qml`](file:///home/mate/dotfiles/config/quickshell/modules/BackgroundModule.qml), `!background`): Switch cleanly between **Folder** slideshows (custom/recent folders, random vs sequential, configurable interval or manual, subfolders toggle, per-monitor vs synced, virtualized thumbnail browser, Bing fetch trigger), **Single Image** (built-in folder gallery or native `zenity` file picker with `.webp` conversion cache and recent strip), **Animated** (only enabled in **Performance** power mode — auto-switches to your fallback static mode on Balanced/Power Saver and restores Animated when returning to Performance; includes 5 GPU fragment shaders — *Aurora Silk*, *Ambient Orbs*, *Starfield*, *Silk Waves*, *Velvet Flow* — with palettes/eyedropper/speed/intensity, or looping `.gif`/video clips converted via `ffmpeg`, auto-pausing on fullscreen), and **Solid** backdrops (swatches, hex/`hyprpicker` eyedropper, vignette). Shared **Effects** include fit mode (`Fill`/`Fit`/`Stretch`/`Center`), crossfade speed, dim, blur, and subtle Ken Burns pan/zoom, persisted in `wallpaper-config.json` and mirrored (blurred) onto the lock screen.

---

## 6. Other Dotfiles & Scripts

- **Fish Shell** ([`config/fish/`](file:///home/mate/dotfiles/config/fish)):
  - [`config.fish`](file:///home/mate/dotfiles/config/fish/config.fish): initializes `starship` and `zoxide`, suppresses greeting.
  - [`conf.d/aliases.fish`](file:///home/mate/dotfiles/config/fish/conf.d/aliases.fish): NixOS helpers (`nixrbd`, `nixupd`, `nixgb`, `nixsyntax`), `rm` → `trash`, `vim` → `nvim`, `neofetch` → `fastfetch -c ~/.config/fastfetch/custom.jsonc`, and `winapps` shortcuts (`word`, `excel`, `ppt`, `win`).
  - [`conf.d/functions.fish`](file:///home/mate/dotfiles/config/fish/conf.d/functions.fish): `vpn` (Tailscale exit-node toggle), `pm` (ACPI `platform_profile`), `cm` (Lenovo IdeaPad conservation mode), `tb` (`termbin.com` pastebin), `nixify` (exports `NIX_LD` / `NIX_LD_LIBRARY_PATH`), `screenoff`, `myip`, `bat`, `vencord`.
- **Kitty** ([`config/kitty/kitty.conf`](file:///home/mate/dotfiles/config/kitty/kitty.conf)): JetBrains Mono Nerd Font Mono, `0.7` background opacity, beam cursor, no decorations, `fish` shell.
- **Neovim** ([`config/nvim/`](file:///home/mate/dotfiles/config/nvim)): Lazy.nvim plugin setup.
- **Qt & KDE COSMIC Dark Theme** ([`config/qt6ct/make-cosmic-shell-theme.py`](file:///home/mate/dotfiles/config/qt6ct/make-cosmic-shell-theme.py)): Generates matching `CosmicShell` palettes/themes for `qt6ct`, KDE (`kdeglobals` + color scheme), and `Kvantum` (`KvArcDark` recolored to match `Theme.qml`).
- **Utility Scripts** ([`scripts/`](file:///home/mate/dotfiles/scripts), linked to `~/.scripts/`):
  - [`tlpmodes.sh`](file:///home/mate/dotfiles/scripts/tlpmodes.sh): switches or cycles `low-power` / `balanced` / `performance` (used by Quickshell's `PowerProfile`).
  - [`bingpaper.sh`](file:///home/mate/dotfiles/scripts/bingpaper.sh): downloads today's 4K Bing wallpaper into `~/Pictures/BingWallpaper`.
  - [`sunshine.sh`](file:///home/mate/dotfiles/scripts/sunshine.sh): creates/removes a headless `REMOTE` Hyprland output for Sunshine/VNC streaming.

---

## 7. Key Configuration Files

| Path | Purpose |
|---|---|
| [`config/hypr/hyprland.lua`](file:///home/mate/dotfiles/config/hypr/hyprland.lua) | Compositor entry point: monitors, touchpad device, and submodule imports. |
| [`config/hypr/conf/scrolling.lua`](file:///home/mate/dotfiles/config/hypr/conf/scrolling.lua) | Scrolling layout settings, column width rules, touchpad gestures, and `SUPER+F` toggle. |
| [`config/hypr/conf/keybinds.lua`](file:///home/mate/dotfiles/config/hypr/conf/keybinds.lua) | Input settings, core/IPC shortcuts, screenshots, media keys, and lid switch hooks. |
| [`config/hypr/conf/rules.lua`](file:///home/mate/dotfiles/config/hypr/conf/rules.lua) | Floating/centering rules, dynamic browser PiP/extension placement, and Quickshell blur rules. |
| [`config/hypr/conf/autostart.lua`](file:///home/mate/dotfiles/config/hypr/conf/autostart.lua) | Startup services (`qs`, `cliphist`, `kdeconnect-indicator`, `hyprsunset`). |
| [`config/hypr/conf/looks.lua`](file:///home/mate/dotfiles/config/hypr/conf/looks.lua) | Borders, gaps, rounding, blur, shadows, animations, and `allow_session_lock_restore`. |
| [`config/hypr/conf/environment.lua`](file:///home/mate/dotfiles/config/hypr/conf/environment.lua) | Wayland environment variables (`TZDIR`, `BROWSER`, `QS_ICON_THEME`, cursor themes). |
| [`config/hypr/hypridle.conf`](file:///home/mate/dotfiles/config/hypr/hypridle.conf) | Idle lock (`245s`), DPMS off (`250s`), suspend (`600s`), sleep hooks, and cursor re-assert. |
| [`config/hypr/scripts/lock.sh`](file:///home/mate/dotfiles/config/hypr/scripts/lock.sh) | Manages the `hcs-lock.service` Quickshell lock instance (`lock` / `sleep` / `wake`). |
| [`config/hypr/scripts/reassert-cursor.sh`](file:///home/mate/dotfiles/config/hypr/scripts/reassert-cursor.sh) | Re-applies cursor theme on DPMS/sleep wake so hardware cursors reappear immediately. |
| [`config/quickshell/shell.qml`](file:///home/mate/dotfiles/config/quickshell/shell.qml) | Main Quickshell entry point (bar, wallpaper, launcher, overview, OSDs, notifications, polkit). |
| [`config/quickshell/lock.qml`](file:///home/mate/dotfiles/config/quickshell/lock.qml) | Lock screen Quickshell entry point. |
| [`config/quickshell/Config.qml`](file:///home/mate/dotfiles/config/quickshell/Config.qml) | User-tunable initial shell defaults (clock format, calendar options, default weather location, wallpaper directory). |
| [`config/quickshell/Theme.qml`](file:///home/mate/dotfiles/config/quickshell/Theme.qml) | Single source of truth for COSMIC Dark colors, spacing, radii, fonts, and default opacities. |
