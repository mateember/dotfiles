# Hyprland COSMIC Shell: User Guide

A modern Wayland desktop environment combining **Hyprland** (configured via the Lua API with a Niri-style scrolling layout) and **Quickshell** (a complete desktop shell themed after System76 COSMIC).

All user configuration lives in `~/dotfiles`:
- Hyprland: `config/hypr/` (symlinked to `~/.config/hypr/`)
- Desktop Shell: `config/quickshell/` (symlinked to `~/.config/quickshell/`)

---

## 1. System Overview & Architecture

```
                       ┌───────────────────────────────────────────────┐
                       │          Hyprland Compositor (Lua API)       │
                       │  - Niri-style scrolling layout                │
                       │  - Gestures & column window management        │
                       │  - Window rules & dynamic SUPER+F width       │
                       └───────┬───────────────────────────────┬───────┘
                               │                               │
                Layer Shell IPC│                  Socket2 Events│
                               ▼                               ▼
       ┌───────────────────────────────────────────────────────────────┐
       │                 Quickshell Desktop Shell (qs)                 │
       │                                                               │
       │  ┌─────────────────────────────────────────────────────────┐  │
       │  │ Top Panel (Bar): 21 modular, reorderable widgets        │  │
       │  └─────────────────────────────────────────────────────────┘  │
       │  ┌───────────────┐  ┌──────────────────┐  ┌────────────────┐  │
       │  │ Launcher      │  │ Overview         │  │ Quick Settings │  │
       │  │ (SUPER Space) │  │ (SUPER Tab)      │  │ (SUPER Comma)  │  │
       │  └───────────────┘  └──────────────────┘  └────────────────┘  │
       │  ┌───────────────┐  ┌──────────────────┐  ┌────────────────┐  │
       │  │ Notifications │  │ Screen Capture   │  │ Wallpaper      │  │
       │  │ & OSD Toasts  │  │ Studio (Print)   │  │ Slideshow      │  │
       │  └───────────────┘  └──────────────────┘  └────────────────┘  │
       └───────────────────────────────────────────────────────────────┘
```

The shell is built with **Qt 6 / QML** via Quickshell, adhering strictly to the **COSMIC Dark Theme** specifications (`Theme.qml`):
- Pure Wayland layer-shell surfaces with background blur.
- Consistent color palettes (Amber accent `#FFAD00`, dark containers, semi-transparent frosted surfaces).
- Native integration with NetworkManager, PipeWire, BlueZ, UPower, TLP, and Evolution Data Server (EDS).

---

## 2. Managing the Environment & Development

### Quick Commands

| Action | Command / Shortcut | Description |
|---|---|---|
| **Restart Shell + Reload Hyprland** | `SUPER + SHIFT + R` | Restarts Quickshell cleanly and triggers `hyprctl reload`. |
| **Restart Shell Only** | `~/.config/hypr/scripts/restart-shell.sh` | Restarts the Quickshell process. |
| **View Shell Logs** | `qs log` | Displays live console output and runtime QML errors. |
| **Check Hyprland Config Errors** | `hyprctl configerrors` | Validates Hyprland Lua syntax. |
| **Hot Reloading** | Edit any file in `config/quickshell/` | Quickshell automatically hot-reloads modified QML files. |
| **Regenerate Lock Screen** | `python3 ~/.config/hypr/hyprlock-gen.py` | Regenerates `hyprlock.conf` based on active monitor resolutions and scales. |

### Development & Customization Workflow

- **Quickshell Hot Reload**:
  - Modifying and saving existing `.qml` files triggers an automatic live reload in Quickshell without restarting the process.
  - If you create a **new subfolder** under `config/quickshell/`, Quickshell's import engine will not detect it automatically; run `~/.config/hypr/scripts/restart-shell.sh` to restart.
  - The restart script ensures the old process is completely terminated before launching a new one so they do not conflict over the bar, IPC, or layer-shell namespaces.
- **Hyprland Lua API**:
  - Configuration reloads automatically on save or via `hyprctl reload`.
  - Check for syntax or configuration issues with `hyprctl configerrors`.
  - For interactive Lua testing, run `hyprctl repl` or evaluate expressions directly with `hyprctl eval '<lua-code>'`.
- **Scripting via Shell IPC**:
  - Quickshell components register `IpcHandler` targets that can be invoked from bash or keybinds:
    - Toggle any bar popup: `qs ipc call bar toggle <name>` (e.g. `volume`, `network`, `clipboard`, `weather`, `calendar`)
    - Next wallpaper: `qs ipc call wallpaper next`
    - Toggle app launcher: `qs ipc call launcher toggle`
    - Toggle overview: `qs ipc call overview toggle`
    - Toggle night light: `qs ipc call nightlight toggle` (or `on` / `off` / `auto`)
    - Cycle power profiles: `qs ipc call powerprofile cycle`

---

## 3. Keybindings Reference

`SUPER` is the Windows / Super key.

### Applications & Desktop Shell

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Space` | **App Launcher** | Fuzzy search for apps, calculator (`=`), commands (`>`), and shell apps (`!`). |
| `SUPER + Tab` / `SUPER + W` | **Overview** | KDE Plasma-style workspace strip with live window previews, search, and window controls. |
| `SUPER + ,` (Comma) | **Quick Settings** | Control center dropdown with toggles, sliders, and media playback. |
| `SUPER + N` | **Notification Center** | Notification history, Do Not Disturb toggle, and current media card. |
| `SUPER + Period` | **Emoji Picker** | Search and paste emojis directly into the focused window. |
| `SUPER + SHIFT + C` | **Clipboard History** | Cliphist manager with search and image previews. |
| `SUPER + SHIFT + P` | **Color Picker** | Eyedropper tool; copies `#RRGGBB` hex to clipboard with an on-screen preview. |
| `SUPER + Print` | **Capture Studio** | Interactive screenshot and screen recording overlay (region, window, display, audio, annotation). |
| `SUPER + L` | **Power Menu** | Session controls: Lock, Suspend, Log out, Restart, Shut down. |
| `SUPER + CTRL + L` | **Lock Screen** | Locks the screen with COSMIC-themed `hyprlock`. |
| `SUPER + C` | Terminal | Launches `kitty`. |
| `SUPER + E` | File Manager | Launches `nautilus` / `thunar`. |
| `SUPER + B` | Web Browser | Launches `brave-origin`. |

### Windows & Workspaces

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Q` | Close Window | Closes the active window. |
| `SUPER + V` | Toggle Floating | Switches window between floating and tiled. |
| `SUPER + M` | Exit Session | Cleanly stops the UWSM session (or exits Hyprland). |
| `SUPER + P` | Pseudotile | Enables pseudotiling mode. |
| `SUPER + J` | Toggle Split | Toggles layout split orientation (in dwindle mode). |
| `SUPER + 1 … 0` | Switch Workspace | Switches to workspace 1 through 10. |
| `SUPER + SHIFT + 1 … 0` | Move to Workspace | Moves the focused window to workspace 1 through 10. |
| `SUPER + S` | Toggle Scratchpad | Shows / hides the special scratchpad workspace (`special:magic`). |
| `SUPER + SHIFT + S` | Move to Scratchpad | Sends the focused window to the scratchpad. |
| `SUPER + Mouse Scroll` | Switch Workspace | Cycles to next / previous workspace. |
| `SUPER + Left Drag` | Move Window | Drags window with the mouse. |
| `SUPER + Right Drag` | Resize Window | Resizes window with the mouse. |
| `SUPER + CTRL + Left Drag` | Resize Window | Alternative resize using mouse drag. |

### Niri-Style Scrolling Layout (`config/hypr/conf/niri.lua`)

Hyprland uses the built-in scrolling layout. Windows open as columns on an endless horizontal strip, with workspaces stacked per monitor.

| Keybind / Gesture | Action | Description |
|---|---|---|
| **`SUPER + F`** | **Smart Width Toggle** | Toggles between **1.0 (fullscreen)** and the window's **previous width**. Windows opening at 1.0 shrink to **0.5 (half-screen)**. If resized to custom sizes (e.g. 0.6, 0.7), it preserves and restores that exact size. |
| **`SUPER + SHIFT + F`** | **True Fullscreen** | Toggles exclusive fullscreen mode. |
| **`SUPER + R`** | Cycle Widths Forward | Cycles through preset column widths: `0.333` → `0.5` → `0.667` → `1.0`. |
| **`SUPER + CTRL + R`** | Cycle Widths Backward | Cycles backwards through preset column widths. |
| **`SUPER + ó` / `SUPER + ü`** | Adjust Width (±10%) | Expands or shrinks the current column width by 10%. |
| **`SUPER + ő` / `SUPER + ú`** | Consume / Expel Window | Pulls the adjacent window into the current column, or expels a window into its own column. |
| **`SUPER + CTRL + C`** | Center Column | Scrolls the horizontal strip so the focused column is centered. |
| **`SUPER + ← / →`** | Focus Column | Moves focus left/right across columns. At the end of the strip, moves to the adjacent monitor. |
| **`SUPER + ↑ / ↓`** | Focus in Column | Moves focus up/down between stacked windows in the same column. |
| **`SUPER + CTRL + ← / →`** | Move Column | Swaps the focused column with the one to the left/right. |
| **`SUPER + CTRL + ↑ / ↓`** | Move in Column | Moves the window up/down inside its vertical column stack. |
| **`SUPER + Page Down / Page Up`**<br>`SUPER + U / I` | Workspace Next / Prev | Moves to the next or previous workspace on this monitor. |
| **`SUPER + CTRL + Page Down / Up`**<br>`SUPER + CTRL + U / I` | Move Window to Workspace | Moves the focused window to the next or previous workspace. |
| **`SUPER + SHIFT + Arrows`** | Focus Monitor | Moves focus to the monitor in that direction. |
| **`SUPER + SHIFT + CTRL + Arrows`**| Move Window to Monitor | Moves the focused window to that monitor and follows focus. |
| **`SUPER + SHIFT + Mouse Scroll`**| Scroll Columns | Scrolls through the columns horizontally. |
| **3-Finger Horizontal Swipe** | Touchpad Column Scroll | 1:1 smooth touchpad scrolling across the horizontal column strip (snaps to column edges). |
| **4-Finger Horizontal Swipe** | Touchpad Workspace Switch | Switches workspaces horizontally. Swiping past the last workspace creates a new one. |
| **4-Finger Vertical Swipe** | Live Overview Swipe | Pulls the Overview down or pushes it away with 1:1 finger tracking. |

#### Automatic Column Width Rules
Terminals (`kitty`, `CosmicTerm`, `foot`, `Alacritty`, `wezterm`, `gnome-terminal`) and File Managers (`nautilus`, `thunar`, `CosmicFiles`, `dolphin`) automatically open at **half width (0.5)**. All other applications open at **full width (1.0)**. Windows are prevented from maximizing themselves on launch to preserve this geometry.

### Hardware & Media Controls

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | Increases volume (wpctl, up to 150%) + OSD toast. |
| `XF86AudioLowerVolume` | Decreases volume + OSD toast. |
| `XF86AudioMute` | Toggles audio mute + OSD toast. |
| `XF86AudioMicMute` | Toggles microphone mute + OSD toast. |
| `XF86MonBrightnessUp / Down` | Adjusts screen brightness by ±10% + OSD toast. |
| `XF86AudioPlay / Pause`, `F11`, `ALT + P` | Toggles media playback (playerctl). |
| `XF86AudioNext` / `XF86AudioPrev` | Skips track forward / backward. |
| Laptop Lid Close | With 1 monitor: suspends system. With external monitor connected: disables laptop display. |
| Laptop Lid Open | Re-enables the laptop display panel. |

---

## 4. Top Panel & Modular Widgets

The top bar (`config/quickshell/bar/Bar.qml`) is a floating pill styled after COSMIC Panel, hosting 21 modular widgets:

| Widget | Left Click | Right / Middle Click | Details |
|---|---|---|---|
| **Workspaces** | Focus workspace | Right/Middle: Opens Overview. Scroll: cycle workspaces | Active workspace is highlighted by an amber circle with **optically centered digits** (including subpixel alignment for `1`). |
| **Clipboard** | Opens clipboard manager | Clear history button in header | Search, navigate with arrows, press Enter to copy; includes image thumbnail previews. |
| **Night Light** | Opens Night Light menu | Right/Middle: Toggle on/off | Temperature slider, manual toggle, or follow schedule (`hyprsunset`). Amber icon when active. |
| **Caffeine** | Toggles keep-awake indefinitely | Right/Middle: Preset timer dropdown | Dropdown offers `Indefinitely`, `15m`, `30m`, `1h`, `2h`, `4h` with a live remaining-time countdown. |
| **System Monitor (Minimon)** | Opens Minimon dashboard | Right/Middle: Opens `btop` / Task Manager | Live sparklines and gauges for CPU, CPU Temp, Memory, Network, Disk, and Intel Arc GPU. Customizable display presets (`Graphs`, `Icons`, `Values`). |
| **Weather** | Opens weather forecast | | Displays current temperature, precipitation chance/mm, wind speed, UV index, and 5-day forecast (Open-Meteo). |
| **Clock & Calendar** | Opens calendar popup | | Month calendar synchronized with **GNOME Calendar / Evolution Data Server (EDS)**. Shows event dots, agenda list, and Nextcloud/Google tasks. |
| **Screen Recorder** | Stops active recording | Right/Middle: Opens Capture Studio | Appears only while recording (`REC MM:SS`); saves recordings to `~/Videos/Recordings/`. |
| **Privacy Indicator** | Shows active mic/cam/screen apps | | Amber indicator appears automatically whenever an application accesses microphone, webcam, or screencopy. |
| **Storage / Removable Drives** | Opens drive management menu | | Appears when a USB drive or SD card is inserted; provides one-click mount, file manager open, and safe ejection (`udisksctl`). |
| **System Tray** | Focuses app | Right click: app context menu | Host for standard StatusNotifierItem (SNI) tray icons (KDE Connect, etc.). |
| **Display & Brightness** | Opens display menu | Scroll: adjust brightness | Controls display brightness, keyboard backlight level (Off/Low/High), and screen refresh rate (`60 Hz` / `120 Hz`). |
| **Tiling Layout** | Toggles scrolling ↔ dwindle | Right click: layout presets & colresize | Allows on-the-fly switching between scrolling and traditional tiling layouts. |
| **Media Player** | Opens media popup | Right/Middle: Play/Pause | Shows album artwork, title, artist, seek bar, volume, and playback controls (MPRIS). |
| **Volume / Audio** | Opens audio mixer | Middle: Toggle Mute. Scroll: adjust volume | Per-app volume sliders, input/output device selector, and pavucontrol shortcut. |
| **Bluetooth** | Opens Bluetooth menu | Middle: Toggle Bluetooth on/off | Lists paired and discovered devices, connection toggles, and connected device battery percentages. |
| **Network & VPN** | Opens network menu | | Includes Ethernet status, full **VPN profile manager** (with connect toggles, edit gears, and inline password prompts), dedicated **Wi-Fi section with on/off switch**, and network list. |
| **Battery & Power** | Opens battery popup | | Battery health and percentage, TLP power profile selector (**Power Saver / Balanced / Performance**), refresh rate toggle, and window blur toggle. |
| **Notifications** | Opens notification center | Middle: Toggle Do Not Disturb | History of past notifications, Clear All button, and current media playback banner. |
| **Quick Settings** | Opens Quick Settings | | Quick toggle tiles, sliders, and power shortcuts (equivalent to `SUPER + ,`). |
| **Power Button** | Opens power menu | | Lock screen, Suspend, Log out, Restart, Shut down (equivalent to `SUPER + L`). |

---

## 5. Shell Customization & Built-In Apps

Quickshell includes standalone configuration tools accessible via the launcher (`SUPER + Space`) or IPC commands:

### Bar Settings (`!bar` or `qs ipc call barsettings toggle`)
An interactive window allowing full customization of the top panel:
- **Toggle visibility** of any of the 21 widgets on or off. (Widgets hidden from the bar can still be opened as centered floating windows from the launcher).
- **Reorder** widgets within each section using **↑ / ↓** buttons.
- **Move** widgets between **Left**, **Center**, and **Right** panel sections.
- **Reset** to default layout.
Settings are automatically saved in `~/.config/quickshell/bar-config.json`.

### Opacity & Transparency (`!opacity` or `qs ipc call opacity toggle`)
Fine-grained opacity control with real-time preview and presets:
- **Widgets**: Opacity of popups, launcher, and floating dialogs (default `96%`).
- **Bar**: Top panel background opacity (default `66%`; `0%` renders floating icons).
- **Notifications**: Notification popup toasts and notification center background (default `96%`).
- **Volume & Brightness Toasts**: On-screen display indicator pills (default `96%`).
- Presets available: **Default**, **Frosted Glass**, **Clear**, and **Solid**.

### App Launcher (`SUPER + Space`)
A unified search and command palette:
- **Application Search**: Type an application name (e.g. `kitty`, `brave`, `thunar`). Frequently used apps are scored higher.
- **Calculator**: Prefix with `=` or type arithmetic directly (e.g. `=2^10 * 3` or `45 * 1.25`) to evaluate via `qalc`. Pressing Enter copies the answer.
- **Terminal Commands**: Prefix with `>` (e.g. `>top` or `>ping 1.1.1.1`). Pressing `Shift + Enter` executes the command inside a terminal window.
- **Emoji Search**: Prefix with `:` (or press `SUPER + Period`) to search emojis (e.g. `:fire`, `:smile`).
- **Quickshell Apps**: Prefix with `!` (or `/`, `@`) to launch shell panels and tools:
  `!bar`, `!opacity`, `!overview`, `!capture`, `!record`, `!wallpaper` (Next Wallpaper), `!colorpicker`, `!power`, `!calendar`, `!weather`, `!network`, `!storage`, `!privacy`, etc.

### Wallpaper Slideshow
- Rotates through images stored in `~/Pictures/BingWallpaper` every 5 minutes.
- Uses smooth crossfading on transition, but switches instantly if a fullscreen window/game is active.
- To advance to the next random wallpaper manually:
  - Select **Next Wallpaper** (`!wallpaper`) in the launcher, or
  - Run `qs ipc call wallpaper next`.

---

## 6. Configuration Files

| Path | Purpose |
|---|---|
| `config/hypr/hyprland.lua` | Main compositor entry point; defines display monitors, devices, and loads submodules. |
| `config/hypr/conf/niri.lua` | Niri-style scrolling layout configuration, column widths, touchpad gestures, and `toggle_width`. |
| `config/hypr/conf/keyboard.lua` | Core keyboard shortcuts, mouse bindings, touchpad sensitivity, and hardware keys. |
| `config/hypr/conf/windowrules.lua` | Window rules for floating popups, Quickshell windows, and file pickers. |
| `config/hypr/conf/autostart.lua` | Services started on compositor launch (`hypridle`, `hyprsunset`, cliphist, `quickshell`). |
| `config/hypr/conf/looks.lua` | Window borders, gaps, rounding, inactive opacity, and animations. |
| `config/hypr/conf/environment.lua` | Wayland environment variables, default browser, icon theme, and timezone directory. |
| `config/hypr/conf/shell.lua` | Launches Quickshell (`qs`) and binds shell shortcuts. |
| `config/hypr/hypridle.conf` | Idle management (screen blanking, locking with hyprlock, system suspend). |
| `config/hypr/hyprlock-gen.py` | Generator script creating `hyprlock.conf` with monitor-specific scaling and geometry. |
| `config/quickshell/Config.qml` | User-tunable shell variables (wallpaper directory, weather coordinates, clock format). |
| `config/quickshell/Theme.qml` | Single source of truth for COSMIC dark colors, radii, spacing, and fonts. |
