# hypr-cosmic-shell: user guide

What changed compared to your old Hyprland setup, how to use it, and every keybind.
Everything lives in `~/dotfiles` (`config/hypr` and `config/quickshell`, linked into `~/.config`) and `~/Nix` on branch `hypr-cosmic-shell`.

Last updated: 2026-10-25.

---

## 0. Switching to the system install

The setup is committed to your own repos on branch `hypr-cosmic-shell`:

| Repo | Commit | What |
|---|---|---|
| `~/dotfiles` | 19728c1 … latest on the branch | `config/hypr` (Lua config, hyprlock, hypridle) and `config/quickshell` (the shell). Linked into `~/.config/hypr` and `~/.config/quickshell`. |
| `~/Nix` | 720714e … latest on the branch | `system/matevono/hyprland-desktop.nix` (session, PAM, portals, polkit, i2c, packages, fonts), `calendar-events.nix`, `configuration.nix` + rofi/waybar/wlogout/awww removed |

To switch:

1. `sudo nixos-rebuild switch --flake ~/Nix#matevono`
2. Delete `~/.config/xdg-desktop-portal/hyprland-portals.conf`, or add
   `org.freedesktop.impl.portal.Secret = kwallet` to it: it overrides the system portal config.
3. Log out, and in cosmic-greeter pick **Hyprland (uwsm-managed)**.
   Hyprland then reads `~/.config/hypr/hyprland.lua` and starts the shell from `~/.config/quickshell`.

Restart the shell with SUPER SHIFT R (`~/.config/hypr/scripts/restart-shell.sh`), check the shell log with
`qs log`, and regenerate the hyprlock layout with `python3 ~/.config/hypr/hyprlock-gen.py`. SUPER M and
the power menu's "Log out" stop the UWSM session.
**Since 2026-10-24 18:42 you run the system install** (UWSM session), and all work happens in the
`~/dotfiles` and `~/Nix` repos (`~/hypr-cosmic-shell` was deleted once everything moved to the git branch).
To undo: `git switch main` in both repos and rebuild.

**Plain "Hyprland" or "Hyprland (uwsm-managed)"?** Either works. The plain session starts
`graphical-session.target` through `~/.config/hypr/scripts/session-target.sh` (see `NIXOS_NOTES.md` §0);
a rebuild adds `hyprland-session.target`, until then the script creates a temporary copy.

## 1. Starting and restarting

| What | How |
|---|---|
| Start the Hyprland session | From cosmic-greeter / GDM: pick **Hyprland (uwsm-managed)** (uses `~/.config/hypr/hyprland.lua`) |
| Restart the shell + reload Hyprland | **SUPER SHIFT R** (or `~/.config/hypr/scripts/restart-shell.sh --reload-hyprland`) |
| Restart only the shell | `~/.config/hypr/scripts/restart-shell.sh` |
| Shell log (errors) | `qs log` |
| Hyprland config errors | `hyprctl configerrors` (should print nothing) |

Editing a file in `~/.config/quickshell/` reloads the shell automatically. A **new folder** in `~/.config/quickshell/`
needs `restart-shell.sh`.

System-level notes and NixOS module details are in `NIXOS_NOTES.md`.

---

## 2. Keybinds

`SUPER` is the Windows key. **Bold** rows changed or are new.

### Apps and shell

| Keys | Action | Before |
|---|---|---|
| **SUPER Space** (on release) | **App launcher** | rofi |
| **SUPER period** | **Emoji picker** | none |
| **SUPER SHIFT C** | **Clipboard history** | rofi + cliphist (had a typo, didn't work) |
| **SUPER SHIFT P** | **Color picker** (click a pixel, `#RRGGBB` is copied) | none |
| **SUPER N** | **Notification center** | none |
| **SUPER L** | **Power menu** (lock, suspend, log out, restart, shut down) | wlogout |
| **SUPER SHIFT R** | **Restart shell + reload Hyprland** (`~/.config/hypr/scripts/restart-shell.sh`) | `hyprestart.sh` (restarted waybar/dunst) |
| **SUPER CTRL L** | **Lock screen** (hyprlock, COSMIC-themed: `hypr/hyprlock.conf`) | none |
| **SUPER comma** | **Quick settings panel** | none |
| **SUPER Tab** / **SUPER W** | **KDE Plasma-style Overview** (workspaces strip + live window previews, search, move/close windows) | none |
| **SUPER Print** | **Interactive Screenshot & Screen Record Studio** (region/window/screen, Copy / Save / Swappy annotate, timer, screen recorder with audio) | none |
| SUPER C | kitty | same |
| SUPER E | Thunar | same |
| **SUPER B** | **Brave (`brave-origin`)** | `brave`, which isn't installed, so it did nothing |

### Windows and workspaces (unchanged)

| Keys | Action |
|---|---|
| SUPER Q | close window |
| SUPER M | exit Hyprland |
| SUPER V | toggle floating |
| **SUPER F** | **maximize / restore (toggle)**, keeps the bar and gaps | was real fullscreen |
| **SUPER SHIFT F** | **real fullscreen (toggle)** | new |
| SUPER P | pseudotile |
| SUPER J | toggle split (dwindle) |
| SUPER ←/→/↑/↓ | move focus |
| SUPER 1…0 | workspace 1…10 |
| SUPER SHIFT 1…0 | move window to workspace 1…10 |
| SUPER S / SUPER SHIFT S | show / move to scratchpad (special:magic) |
| SUPER scroll | next / previous workspace |
| SUPER left drag / SUPER CTRL left drag | move / resize window |
| SUPER right drag | resize window |
| SUPER SHIFT F23 | send Right Ctrl (wtype) |

### Niri-style scrolling (new, `hypr/conf/niri.lua`)

Windows open as columns on an endless horizontal strip. Workspaces slide horizontally per monitor.

| Keys / gesture | Action |
|---|---|
| **3 fingers left/right** | scroll the strip (follows your fingers, settles on a column) |
| **4 fingers left/right** | previous / next workspace (past the last one opens a new empty one) |
| **4 fingers up / down** | bring **Overview** up / down (follows your fingers 1:1 with smooth slide/scale animation) |
| SUPER ←/→ (unchanged) | focus the column left/right; at the end of the strip, the next monitor |
| SUPER ↑/↓ (unchanged) | focus the window above/below in the same column |
| **SUPER CTRL ←/→** | move the column left/right |
| **SUPER CTRL ↑/↓** | move the window up/down inside its column |
| **SUPER Page Down / Page Up**, **SUPER U / I** | next / previous workspace on this monitor |
| **SUPER CTRL Page Down / Page Up**, **SUPER CTRL U / I** | move the window to the next / previous workspace |
| **SUPER SHIFT ←/→/↑/↓** | focus the monitor in that direction |
| **SUPER SHIFT CTRL ←/→/↑/↓** | move the window to that monitor |
| **SUPER R / SUPER CTRL R** | cycle column width 1/3 → 1/2 → 2/3 → full (forward / back) |
| **SUPER ü / SUPER ó** | column width −10 % / +10 % |
| **SUPER ő** | pull the window into the column on the left, or push it out into its own column |
| **SUPER ú** | same, toward the right |
| **SUPER CTRL C** | center the column |
| **SUPER SHIFT scroll** | scroll through columns (SUPER scroll still switches workspaces) |

Column widths when a window opens: terminals (kitty, COSMIC Terminal, foot, Alacritty, WezTerm, GNOME Console)
and file managers (Thunar, COSMIC Files, Nautilus, Dolphin) get **half** the screen; everything else
gets the **full** width. Apps can no longer maximize themselves (kitty used to); use SUPER F.
A strip narrower than the screen (e.g. one terminal) is shown centered; Hyprland can't left-align it.

Back to the old dwindle tiling: click the layout icon on the bar (toggles scrolling ↔ dwindle until the next
reload), or comment out `require("conf.niri")` in `hypr/hyprland.lua` for good.

### Hardware keys (unchanged)

| Keys | Action |
|---|---|
| Volume up/down (hold to repeat), Mute | wpctl, max 150 %; now also shows an on-screen indicator |
| Brightness up/down | brightnessctl ±10 %; now also shows an on-screen indicator |
| Play, F11, ALT P | play/pause |
| Next / Previous | playerctl |
| Print / ALT Print / SHIFT Print | screenshot screen / window / region to clipboard (hyprshot) |
| Lid closed | one monitor: suspend; with the Dell: turn off the laptop panel |
| Lid opened | turn the laptop panel back on |

---

## 3. The bar

Left to right. Click an icon for its menu; Escape or a click outside closes it.

| Item | Click | Other |
|---|---|---|
| Workspaces | the workspaces that exist on this monitor (with windows, or currently shown); click to switch | right/middle click = Overview; scroll: one workspace per wheel notch (touchpad: per notch-sized swipe), at most 4 per second |
| Clipboard | history: search, ↑/↓, Enter copies, image previews | ✕ deletes one, top icon clears all |
| Moon | night light: popup with on/off, warmth slider, "Follow schedule" (hyprsunset.conf, 20:00–08:30) | right/middle click = toggle; amber when the screen is warmed |
| Coffee cup | caffeine: left click toggles on indefinitely, or turns off if currently active (timed or indefinite) | right/middle click = dropdown menu for fixed intervals (`Indefinitely`, `15 min`, `30 min`, `1 h`, `2 h`, `4 h`) with live countdown |
| System Monitor (Minimon) | modular dropdown (`General settings`, `CPU`, `CPU Temperature`, `Memory`, `Network`, `Disk`, `GPU`) with live sparkline charts, per-sensor bar toggles (`Prefix in bar: Off / Icon / CPU…`, `Show value in bar`, `Chart in bar: Off / Graph / Ring`), quick style presets (`Graphs`, `Icons`, `CPU/MEM`), and top button to open System Monitor / `btop` | right/middle click = open System Monitor / `btop`; temperature turns orange at 80 °C, red at 90 °C |
| Weather | today's details (rain chance + mm, humidity, wind + direction + gusts, UV, pressure, sunrise/sunset) and 5-day forecast with rain chance | Open-Meteo for Gyömrő, cached for offline |
| Date/time | month calendar with your events: "Next up" line, dots under days with events (calendar colors), agenda of the selected day | click a day to see its events; click an event or double-click a day = GNOME Calendar; buttons open GNOME Calendar and Date & Time settings |
| Screen Recorder (`REC MM:SS`) | appears while recording; left click stops & saves recording to `~/Videos/Recordings/` | right/middle click = open Capture & Record Overlay |
| Privacy pill (amber) | appears when an app uses your microphone, webcam, or screen; click to see which apps and mute mic / stop recording | auto-hides when idle |
| USB / Removable Drives | appears when a USB or SD drive is plugged in; click to open in Files, mount, or safely eject (`udisksctl unmount` + `power-off`), or toggle automount | auto-hides when no removable drive is connected |
| Tray | app tray icons (KDE Connect, …) | right click = app menu |
| Monitor | brightness, **keyboard backlight**, **refresh rate (`60 Hz` / `120 Hz`)**, monitors, screenshots, screen recording, color picker | scroll = brightness |
| Layout | toggles scrolling (niri) ↔ dwindle | right click = all layouts, cycle column width, center column, toggle split |
| Play | player: cover, seek, controls, player switcher | right or middle click = pause/resume |
| Speaker | output/input volume, devices, per-app volume | scroll = volume, middle click = mute |
| Bluetooth | on/off, connect/pair devices, **connected device battery %** | middle click = on/off |
| Wi-Fi | on/off, networks, password prompt | right click a saved network = forget |
| Battery | charge, time left, health, power mode selector (Power Saver / Balanced / Performance) | |
| Bell | notification center + do-not-disturb, now-playing card at the top | middle click = do-not-disturb |
| Sliders (tune) | quick settings panel (same as SUPER comma) | click again to close |
| Power | power menu (same as SUPER L) | |

Settings buttons in the menus open the matching app:
Bluetooth, Wi-Fi, Network, Sound, Displays, Power, Date & Time → COSMIC Settings page;
the tune icon in Sound → pavucontrol; Media → "Open <player>".

### Bar Settings (`!bar` in the launcher, or `qs ipc call barsettings toggle`)

Opens the **Bar Settings** window where you can:
- **Toggle** any of the 18 bar items on or off. (When an item is hidden on the bar, opening it from the `!` launcher menu, Quick Settings `>` chevron, or its keybind opens it as a centered floating window.)
- **Reorder** items within each section using the **↑ / ↓** buttons.
- **Move** an item between **Left**, **Center**, and **Right** by clicking its section pill.
- **Reset** the bar back to the default layout.
Changes take effect immediately and are saved across restarts.

### Calendar events

The calendar popup shows every calendar that's checked in **GNOME Calendar** (Nextcloud, Google, Neptun,
holidays, birthdays) plus tasks that have a due date. Accounts are managed in GNOME Calendar / Online
Accounts; the shell only reads what Evolution Data Server has synced (no passwords). Refreshes when you
open the popup, change month, and every 15 min; the last result is cached for offline use ("offline" label).
- Hide a calendar: uncheck it in GNOME Calendar, or add its name to `calendarHidden` in
  `~/.config/quickshell/Config.qml`. Tasks off: `calendarShowTasks: false`.
- Command line: `hcs-calendar-events 2026-10-01 2026-11-01` prints the events as JSON (after the rebuild).

### Keyboard backlight

In the monitor menu: **Low / High** set the level, the switch turns it off and back on at the last level.
The shell shows the level you last chose there (it doesn't read the hardware, so a change made with
the Fn key isn't reflected). The choice is remembered across restarts.

---

### Quick settings (SUPER comma, or the sliders icon left of the power button)

Top right panel:
- **Tiles** (click = on/off, amber = on, chevron = open the full menu): Wi-Fi, Bluetooth, Night light,
  Do not disturb, Caffeine, Keyboard light (click cycles Off → Low → High), Layout (scrolling ↔ dwindle),
  Power mode (click cycles Power Saver → Balanced → Performance via `~/dotfiles/scripts/tlpmodes.sh`; chevron opens the battery menu).
- **Sliders**: volume (icon = mute, chevron = sound menu), microphone, screen brightness.
- **Now playing** with previous / play-pause / next (also at the top of the notification center).
- **Footer**: battery, region screenshot, COSMIC Settings, lock, power menu.

Escape or a click outside closes it.

## 4. Launcher (SUPER Space)

| Type | Result |
|---|---|
| any text | fuzzy app search; apps you open often rank higher |
| `=2^10*3` (or just `2*21`) | calculator (qalc); Enter copies the result |
| `>command` | run a command; Shift+Enter runs it in kitty |
| `:fire` (or SUPER period) | emoji; Enter types it into the focused window and copies it, Shift+Enter only copies |
| `!` (or `/`, `@`) | **Quickshell apps & panels** (open as centered floating windows when launched here): Bar Settings, Quick Settings, Calendar, Weather, Clipboard, Notifications, Volume, Network, Bluetooth, Display, Media, Night Light, Battery, Layout, Color Picker, Next Wallpaper, Power Menu |

↑/↓, Tab, Ctrl+J/K select · Enter launches · Escape or a click outside closes.

---

## 5. What the shell does in the background

| Feature | Details | Replaces |
|---|---|---|
| Notifications | pop-ups top right (linger ~4.5 s then smoothly fade away; hover pauses), history in the bell menu, do-not-disturb (critical still shown), action buttons; **clicking a toast or notification in the menu invokes the app's target action and focuses its window/workspace** (or opens saved files) | dunst (was never installed) |
| On-screen indicators | bottom center: volume, mute, microphone mute, output device change, brightness, keyboard backlight, caffeine, do-not-disturb, Wi-Fi, Bluetooth, layout, charger plugged/unplugged | none |
| Low battery | notification below 20 % (normal) and below 10 % (critical, sticky even in DND) | none |
| Password prompts (polkit) | COSMIC-styled dialog for pkexec, mounting, system settings | polkit-gnome (stopped for this session when the shell starts) |
| Wallpaper | random image from `~/Pictures/BingWallpaper` per monitor every 5 min, crossfade, instant while a fullscreen window is open | `swww.sh` / awww |
| Tray host | shows StatusNotifier icons | waybar's tray |

Started at login by the config (`hypr/conf/autostart.lua`): hypridle (project copy), hyprsunset,
cliphist watchers, kdeconnect-indicator, the shell.

---

## 6. What changed in the config files

All in `~/dotfiles/config/hypr/` (`~/.config/hypr/`) and `~/dotfiles/config/quickshell/` (`~/.config/quickshell/`).

**Format:** hyprlang (`.conf`) → Lua (`.lua`), because Hyprland 0.57 drops hyprlang.
Same structure: `hyprland.lua` loads `conf/keyboard.lua`, `windowrules.lua`, `autostart.lua`,
`looks.lua`, `environment.lua`, plus the new `conf/niri.lua` and `conf/shell.lua`.

| File | Changes vs. your original |
|---|---|
| `hyprland.lua` | same monitors and touchpad settings; loads `conf/shell.lua` last |
| `conf/keyboard.lua` | same binds, except: SUPER F now toggles maximize (fullscreen moved to SUPER SHIFT F); SUPER Space, SUPER SHIFT C, SUPER L, SUPER SHIFT R now use the shell (table above). SUPER J uses `layout("togglesplit")` because the old dispatcher was removed in 0.54. Lid binds do in Lua what `monitor_check.sh` and `hyprctl keyword` did. SUPER B opens `brave-origin`. |
| `conf/windowrules.lua` | same rules, same order, Lua syntax; plus `float = true, center = true` for Quickshell standalone windows (`org.quickshell` / `HCS — *`) and all desktop portal / screen-share picker dialogs (`hyprland-share-picker`, `xdg-desktop-portal-*`, `org.freedesktop.impl.portal.desktop.*`) |
| `conf/looks.lua` | same values; `dwindle:pseudotile` removed (option no longer exists, pseudotile still works) |
| `conf/environment.lua` | same variables, except `BROWSER=brave-origin` (was `brave`, not installed), `QS_ICON_THEME=Pop`, `TZDIR=/etc/zoneinfo` |
| `conf/autostart.lua` | waybar, dunst, swww.sh removed; starts `hypridle`, `kdeconnect-indicator`, `hyprsunset`, cliphist watchers, and `quickshell` |
| `conf/niri.lua` | new: scrolling layout as default, touchpad gestures (3-finger horizontal column scroll, 4-finger horizontal workspace switch, 4-finger vertical live Overview swipe), niri-style binds, half/full column width rules, apps can't self-maximize |
| `conf/shell.lua` | new: starts the shell, new binds (SUPER N, CTRL L, comma, period, SHIFT P, Tab / W), blur for shell surfaces |
| `hypridle.conf` | screen-off commands use Lua syntax; locks with `hyprlock` (pauses media before suspend, not on lock) |
| `hyprlock.conf` | new COSMIC-themed lock screen (clean blurred background without dark card, clock, date, avatar, greeting, password pill, now-playing track, battery), generated per monitor scale by `hyprlock-gen.py` (edit that, then run `python3 ~/.config/hypr/hyprlock-gen.py`) |
| `scripts/restart-shell.sh` | restarts Quickshell (and optionally reloads Hyprland + regenerates `hyprlock.conf`) |
| `scripts/session-target.sh` | manual workaround for screen sharing in a plain non-UWSM session (`NIXOS_NOTES.md` §0) |
| `hyprland.conf`, `conf/*.conf` | legacy hyprlang files (kept on `main` branch; `hyprland.lua` is used on `hypr-cosmic-shell`) |

---

## 7. Known issues and open items

- **Screen sharing / portals / `xdg-open`** need `graphical-session.target`: started by the autostart script
  in a plain session, by UWSM otherwise.
- The **polkit prompt** hasn't been tested with a real request yet. Try `pkexec true` in a terminal.
- External monitor (Dell) brightness needs i2c access: see `NIXOS_NOTES.md` §2.
- Packages and config folders you can remove later: `NIXOS_NOTES.md` §3.

For the full development log (every step and decision), see `PROGRESS.md`.
