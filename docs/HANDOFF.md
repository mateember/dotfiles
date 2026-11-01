# Developer Handoff

This document provides context, conventions, and status for developers and agent sessions working on this repository.

---

## 1. Project Overview & Codebase Structure

The project is a custom Wayland desktop environment running on NixOS:
- **Hyprland (Lua API, version >= 0.55)**: Configured in `~/dotfiles/config/hypr/` (symlinked to `~/.config/hypr/`).
- **Quickshell (qs 0.3.2)**: Desktop shell in `~/dotfiles/config/quickshell/` (symlinked to `~/.config/quickshell/`).
- **Documentation**: Located in `~/dotfiles/docs/`:
  - `USER_GUIDE.md`: Full user guide, keybindings, and widget documentation.
  - `HANDOFF.md`: This architecture and development handoff document.
  - `PROGRESS.md`: Historical implementation and development log.

### Key File Locations

```
~/dotfiles/
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua            # Compositor entry point (monitors, devices, includes)
│   │   ├── conf/
│   │   │   ├── niri.lua            # Scrolling layout, column width rules, gestures, SUPER+F toggle
│   │   │   ├── keyboard.lua        # Input devices, core shortcuts, hardware keys
│   │   │   ├── windowrules.lua     # Window floating, centering, and sizing rules
│   │   │   ├── autostart.lua       # Background services (hypridle, hyprsunset, quickshell)
│   │   │   ├── looks.lua           # Borders, gaps, blur, inactive opacity
│   │   │   ├── environment.lua     # Wayland environment variables (TZDIR, BROWSER, QS_ICON_THEME)
│   │   │   └── shell.lua           # Shell launch command and shell-specific binds
│   │   ├── scripts/
│   │   │   └── restart-shell.sh    # Script to restart Quickshell cleanly (SUPER+SHIFT+R)
│   │   ├── hypridle.conf           # Idle timeouts for lock and screen power
│   │   └── hyprlock-gen.py         # Monitor-aware generator for hyprlock.conf
│   └── quickshell/
│       ├── shell.qml               # Quickshell root, variants over screens, global IPC
│       ├── Theme.qml               # Single source of truth for colors, typography, spacing (COSMIC Dark)
│       ├── Config.qml              # User-tunable shell properties (weather, wallpaper directory)
│       ├── bar/                    # Top panel (Bar.qml), Overview, Bar Settings, Opacity Settings
│       ├── modules/                # 21 modular widgets for the top panel
│       ├── services/               # Singletons (Net, Bt, Notifs, Wallpapers, SystemStats, etc.)
│       ├── components/             # Reusable UI primitives (Popup, ListItem, Toggle, StyledText, Icon)
│       ├── launcher/               # Unified App & Shell Launcher (SUPER+Space)
│       ├── quicksettings/          # Quick Settings dropdown panel (SUPER+Comma)
│       └── wallpaper/              # Background wallpaper layer surface
```

---

## 2. Working Rules & Guidelines

1. **Keep Responses Concise**:
   - Deliver clear, direct answers without unnecessary conversational filler.
   - Format paths and symbols as clickable markdown links (`file:///...`).
2. **Commands & Timeouts**:
   - Wrap interactive CLI commands (`qs`, `hyprctl`, `systemctl`, `busctl`) in a reasonable timeout (e.g. `timeout 5 ...`) to prevent stalled processes.
3. **Preserve User Files**:
   - The user has personal, uncommitted changes in files such as `config/hypr/conf/keyboard.lua` (sensitivity/accel_profile) and `config/fish/config.fish`.
   - **Never revert, overwrite, or stage/commit these files** unless explicitly requested.
4. **Scratch Files & Screenshots**:
   - Always place temporary test scripts, screenshots (`grim`), and cropped images in `/tmp` (never in `~/dotfiles` or `~`).
5. **Quickshell QML Conventions**:
   - Never name a custom property starting with `onXxx` (reserved for signal handlers in Qt).
   - Use `StyledText` instead of standard `Text` to ensure proper `styleName` weight mapping with Fira Sans.
   - Use `Icon` with Material Symbols Rounded glyph names.
   - Source all colors, spacing, and corner radii from `Theme.qml`.
   - After creating a new subfolder in `config/quickshell/`, restart Quickshell via `restart-shell.sh` (hot-reload only monitors existing directories).

---

## 3. Key Components & Implementation Details

### Niri-Style Scrolling Layout (`config/hypr/conf/niri.lua`)
- Hyprland runs the `scrolling` layout as default.
- Terminals and file managers open at `0.5` width; other applications open at `1.0`.
- **`SUPER + F` Smart Width Toggle**:
  - Dynamically inspects the window's current width ratio.
  - If `< 0.85`: remembers its exact width ratio in a Lua table `prev_widths[w.address]` and resizes to `1.0`.
  - If `>= 0.85`: restores `prev_widths[w.address]`. If the window opened at full width without a saved prior size, it defaults to `0.5`.
  - Unbinds `SUPER + F` before binding to prevent collision with legacy maximize dispatchers.

### Workspaces Optical Centering (`config/quickshell/modules/Workspaces.qml`)
- Workspace digits are centered inside active amber circles using `tightBoundingRect`.
- Because the digit `1` in Fira Sans has a prominent top-left flag and no bottom serif, pure bounding-box centering pushes its vertical stem to the right.
- An `opticalOffsets` map (`"1": -1.5`) applies subpixel adjustment so the stem sits dead-center in the circle.

### Network & VPN Module (`config/quickshell/modules/NetworkModule.qml`)
- Top `PopupHeader` provides the title "Network" and a settings gear opening `["cosmic-settings", "network"]`.
- The Wi-Fi on/off switch (`Toggle`) is placed directly beside the "Wi-Fi" section title.
- The VPN manager tracks connections, supports interactive inline password prompts, and routes configuration to `nm-connection-editor`.

### Wallpaper Slideshow (`config/quickshell/services/Wallpapers.qml`)
- Slideshow sources images from `~/Pictures/BingWallpaper` every 5 minutes.
- `Wallpapers` exposes `next()` on its root singleton to allow manual rotation from both the launcher app (`qs:wallpaper`) and IPC (`qs ipc call wallpaper next`).

---

## 4. Development Workflow, Testing & Debugging

### Shell Management & Restart Script
Quickshell owns system-level singletons (StatusNotifier tray, notifications D-Bus name `org.freedesktop.Notifications`, and layer-shell namespaces `hcs-bar`, `hcs-wallpaper`). Running two instances simultaneously causes socket and namespace conflicts.

Always use the restart script:
```bash
# Restart Quickshell cleanly (kills old instance first)
~/.config/hypr/scripts/restart-shell.sh

# Restart Quickshell AND reload Hyprland configuration
~/.config/hypr/scripts/restart-shell.sh --reload-hyprland
# (Or press SUPER + SHIFT + R from anywhere)
```

### Hot Reloading vs. Restarting
- **Existing files**: Saving any `.qml` file in `config/quickshell/` triggers an immediate hot-reload.
- **New folders**: Adding a new directory under `config/quickshell/` (e.g. creating a new module or service category) requires running `restart-shell.sh` so Qt QML import scanners register the path.

### Logs & Error Checking
```bash
# Monitor live Quickshell logs (QML runtime warnings, JS exceptions)
qs log

# Check Hyprland Lua syntax errors
hyprctl configerrors
```

### IPC Scripting & Testing
You can interact with and trigger shell components directly from the command line:
```bash
# Toggle bar popups (volume, network, bluetooth, clipboard, weather, calendar, etc.)
qs ipc call bar toggle network
qs ipc call bar toggle volume

# Trigger shell actions
qs ipc call wallpaper next          # Switch to next random Bing wallpaper
qs ipc call launcher toggle         # Toggle app launcher
qs ipc call overview toggle         # Toggle Overview
qs ipc call barsettings toggle      # Toggle Bar Settings window
qs ipc call opacity toggle          # Toggle Opacity & Transparency window
qs ipc call nightlight toggle       # Toggle night light
qs ipc call powerprofile cycle      # Cycle power mode (Power Saver -> Balanced -> Performance)
```

### Adding a New Bar Widget
1. Create `config/quickshell/modules/MyWidget.qml` using `BarButton`, `Popup`, `StyledText`, and `Icon`.
2. Register the component in `config/quickshell/bar/Bar.qml`:
   - Add `Component { id: compMyWidget; MyWidget {} }`
   - Add `case "mywidget": return compMyWidget;` in `moduleComponent()`.
3. Register the widget in `config/quickshell/services/BarConfig.qml` with its default section (`left`, `center`, or `right`).
4. Restart Quickshell via `~/.config/hypr/scripts/restart-shell.sh`.
