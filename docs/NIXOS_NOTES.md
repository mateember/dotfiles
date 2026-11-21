# NixOS System Notes

System-level NixOS configuration required by this dotfiles setup (configured in `~/Nix`).

## 1. Hyprland UWSM Session, `hypridle` & `TZDIR`

Enable Hyprland with UWSM so `graphical-session.target` starts and `xdg-desktop-portal` (screen sharing, file pickers, `xdg-open`) works properly:

```nix
programs.hyprland = {
  enable = true;
  withUWSM = true;
  xwayland.enable = true;
};
```

- Because NixOS wraps `Hyprland` with `cap_sys_nice`, glibc strips `TZDIR` from its environment. [`config/hypr/conf/environment.lua`](file:///home/mate/dotfiles/config/hypr/conf/environment.lua) restores `TZDIR=/etc/zoneinfo` for child processes.
- `hypridle` runs as a systemd user service (`services.hypridle.enable = true`, scoped to `XDG_CURRENT_DESKTOP=Hyprland`) rather than from [`autostart.lua`](file:///home/mate/dotfiles/config/hypr/conf/autostart.lua). Add the system and user profile paths (`/run/current-system/sw`, `/etc/profiles/per-user/<user>`) to `systemd.user.services.hypridle.path` because [`hypridle.conf`](file:///home/mate/dotfiles/config/hypr/hypridle.conf) and [`lock.sh`](file:///home/mate/dotfiles/config/hypr/scripts/lock.sh) invoke `qs`, `systemd-run`, `hyprctl`, `playerctl`, and `systemctl`.
- UWSM runs XDG autostart entries; hide `polkit-gnome` (and `nm-applet` if present) in Hyprland (`NotShowIn=Hyprland;` or `ConditionEnvironment=!XDG_CURRENT_DESKTOP=Hyprland`) so they do not conflict with Quickshell's built-in Polkit agent ([`PolkitPrompt.qml`](file:///home/mate/dotfiles/config/quickshell/polkit/PolkitPrompt.qml)) and Network widget.

## 2. Lock Screen PAM Services & Howdy

[`LockScreen.qml`](file:///home/mate/dotfiles/config/quickshell/lock/LockScreen.qml) runs two parallel `PamContext` conversations via transient unit `hcs-lock.service`:
- `qs-lock`: pure `pam_unix` password authentication (unlocks immediately without waiting on biometric timeouts).
- `qs-lock-face`: Howdy IR facial recognition (`pam_howdy.so`) when Howdy is installed, enabled, the camera exists, and the user has an enrolled model.

Define both PAM services under `security.pam.services` in NixOS (`qs-lock = {};` and `qs-lock-face.howdy.enable = true;`), and keep `security.pam.howdy.enable = false` globally so greeter login still requires a password and unlocks KWallet. If using an integrated IR camera, also enable `services.howdy` and `services.linux-enable-ir-emitter`.

## 3. Display, External Monitor Brightness (DDC/CI) & Cursors

- Laptop backlight and keyboard backlight controls in [`Brightness.qml`](file:///home/mate/dotfiles/config/quickshell/services/Brightness.qml) require `brightnessctl`.
- External monitor brightness sliders require `ddcutil` plus I2C access:

```nix
hardware.i2c.enable = true;
users.users.mate.extraGroups = [ "i2c" ];
```

- Hardware cursors are kept enabled in [`looks.lua`](file:///home/mate/dotfiles/config/hypr/conf/looks.lua); [`reassert-cursor.sh`](file:///home/mate/dotfiles/config/hypr/scripts/reassert-cursor.sh) re-applies `BreezeX-Black` after DPMS wake.

## 4. Power Mode (`tlpmodes.sh`) Sudo Rules

Quickshell's [`PowerProfile.qml`](file:///home/mate/dotfiles/config/quickshell/services/PowerProfile.qml) invokes [`scripts/tlpmodes.sh`](file:///home/mate/dotfiles/scripts/tlpmodes.sh) as your regular user. **Do not** grant `NOPASSWD` sudo on a user-writable script (`~/dotfiles/scripts/tlpmodes.sh`) or wildcard `tee /sys/devices/system/cpu/cpu*/...` rules (in `sudoers`, `*` matches spaces and `/`, allowing arbitrary root file overwrites).

Instead, expose a single immutable, root-owned `/nix/store` helper (`hcs-tlp-mode`) that validates its single mode argument and performs the `tlp` + sysfs writes internally (`tlpmodes.sh` automatically delegates to `sudo -n hcs-tlp-mode` when present):

```nix
let
  hcsTlpMode = pkgs.writeShellScriptBin "hcs-tlp-mode" ''
    set -euo pipefail
    case "''${1:-}" in
      low)
        ${pkgs.tlp}/bin/tlp bat >/dev/null
        printf 'low-power\n' > /sys/firmware/acpi/platform_profile
        ;;
      balanced)
        ${pkgs.tlp}/bin/tlp bat >/dev/null
        printf 'balanced\n' > /sys/firmware/acpi/platform_profile
        for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
          [ -f "$epp" ] && printf 'balance_performance\n' > "$epp" || true
        done
        ;;
      performance)
        ${pkgs.tlp}/bin/tlp ac >/dev/null
        printf 'performance\n' > /sys/firmware/acpi/platform_profile
        ;;
      auto)
        ${pkgs.tlp}/bin/tlp start >/dev/null
        ;;
      *)
        exit 2
        ;;
    esac
  '';
in {
  environment.systemPackages = [ hcsTlpMode ];
  security.sudo.extraRules = [{
    users = [ "mate" ];
    commands = [{
      command = "${hcsTlpMode}/bin/hcs-tlp-mode";
      options = [ "NOPASSWD" ];
    }];
  }];
}
```

## 5. Desktop Shell Dependencies

- **COSMIC-Style Freeze/Crop Overlay, Capture & Recording** ([`Snip.qml`](file:///home/mate/dotfiles/config/quickshell/services/Snip.qml), [`SnipOverlay.qml`](file:///home/mate/dotfiles/config/quickshell/bar/SnipOverlay.qml), [`capture.sh`](file:///home/mate/dotfiles/config/quickshell/scripts/capture.sh)):
  - `grim`: freezes monitors at native DPI (`grim -l 0 -o ...`) for the interactive `Rectangle`/`Window`/`Screen` overlay and takes quick direct shots (`CTRL+Print`, `CTRL+SHIFT+Print`).
  - `ffmpeg`: crops frozen monitor frames cleanly at physical pixel coordinates in `capture.sh commit`.
  - `slurp`: quick region/window geometry fallback in `capture.sh shot`.
  - `satty` (preferred, with `swappy` fallback): screenshot annotation editor (`--copy-command wl-copy`).
  - `jq`, `wl-clipboard` (`wl-copy`), and `libnotify` (`notify-send`).
  - `wf-recorder` or `wl-screenrec` (plus PipeWire PulseAudio compat `pactl`) for screen recording with optional system/mic audio.
  - `hyprpicker`: color picker (`SUPER + SHIFT + P`, Capture Studio, and Theme/Background eyedroppers).
- **Hardware, Privacy, VPN & Storage Helpers** ([`hardware-status.py`](file:///home/mate/dotfiles/config/quickshell/scripts/hardware-status.py)):
  - `python3`
  - **Privacy Indicator**: `pipewire` (`pw-dump`) for active mic, camera, and screenshare streams.
  - **Removable Drives**: `services.udisks2.enable = true` (`udisksctl`, `lsblk`, `udevadm`, `xdg-open`).
  - **Network & VPN**: `networkmanager` (`nmcli` for Wi-Fi, VPN/WireGuard state & inline password prompts) and `networkmanagerapplet` (`nm-connection-editor` fallback).
  - **Bluetooth & Power**: `bluez`, `services.upower.enable = true` (`upower -d` for Bluetooth device battery percentages).
- **Calendar Events & Weather**:
  - **Calendar**: `hcs-calendar-events` wrapper providing Python + `pygobject3` with `evolution-data-server`, `libical`, `glib`, `gobject-introspection`, `libsoup_3`, and `json-glib` typelibs to run [`calendar-events.py`](file:///home/mate/dotfiles/config/quickshell/scripts/calendar-events.py) against `services.gnome.evolution-data-server.enable = true` (plus `gnome-online-accounts` and `gnome-calendar`).
  - **Weather**: [`hungaromet.py`](file:///home/mate/dotfiles/config/quickshell/scripts/hungaromet.py) uses `python3` stdlib only.
- **Launcher, Clipboard & System Monitor**:
  - `HCS_EMOJI_FILE` environment variable pointing to Unicode's `emoji-test.txt` (`unicode-emoji`), plus `wtype` and `wl-clipboard` for the `:name` / `SUPER + .` emoji picker.
  - `libqalculate` (`qalc`) for inline launcher math, `cliphist` + `wl-paste` (started in [`autostart.lua`](file:///home/mate/dotfiles/config/hypr/conf/autostart.lua)) for clipboard history, and `kitty` + `btop` (or `cosmic-observatory` / `gnome-system-monitor`) for terminal commands and the System Stats monitor button.
- **Background Selector, Bing Fetcher & Animated Wallpapers**:
  - `zenity` (native folder/media pickers), `curl` & `jq` ([`bingpaper.sh`](file:///home/mate/dotfiles/scripts/bingpaper.sh)), `ffmpeg` / `ffprobe` (APNG detection and animated WebP/GIF fallback conversion matching Hyprland's refresh rate), and `qt6.qtshadertools` (`qsb`, only needed when recompiling [GLSL fragment shaders](file:///home/mate/dotfiles/config/quickshell/wallpaper/shaders/compile.sh)).
  - **Native High-Framerate (up to 120+ fps) Video, APNG & Animated WebP Wallpapers**: Upstream `quickshell` only wraps `qtbase`, `qtsvg`, `qtdeclarative`, and `qtwayland`. Wrap `quickshell` with `qt6.qtmultimedia` and `qt6.qtimageformats` (without rebuilding Quickshell from source) so Qt's FFmpeg media backend plays full-framerate/resolution `.mp4`/`.webm`/`.mkv`/`.mov` and `.apng`/animated `.png` wallpapers natively via [`VideoLayer.qml`](file:///home/mate/dotfiles/config/quickshell/wallpaper/VideoLayer.qml) matching Hyprland's output refresh rate (e.g. `120 Hz` on `eDP-1`), and `libqwebp.so` decodes static & animated `.webp` directly in QML (and enables `libwebp_anim` fallback at Hyprland's refresh rate instead of GIF's 50 fps Qt limit):

```nix
let
  qsWithMedia = pkgs.symlinkJoin {
    name = "quickshell-with-media";
    paths = [ pkgs.quickshell ]; # or inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/qs $out/bin/quickshell; do
        [ -e "$bin" ] && wrapProgram "$bin" \
          --prefix QT_PLUGIN_PATH : "${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins:${pkgs.qt6.qtimageformats}/lib/qt-6/plugins" \
          --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml"
      done
    '';
  };
in {
  environment.systemPackages = [ qsWithMedia /* ... */ ];
}
```
- **System Controls, Qt Theming, Icons & Fonts**:
  - `hyprsunset`, `playerctl`, `pavucontrol`, `kdePackages.kdeconnect-kde` (`kdeconnect-indicator`, `kdeconnect-cli`), `pipewire` (`pw-play` + `sound-theme-freedesktop` for optional UI sound cues), `tailscale` (optional exit-node switcher in Settings → Network; set `tailscale set --operator=$USER` or use Polkit prompt), `xdg-utils` (`xdg-mime`), `glib` (`gsettings` for GTK dark/light sync), `qt6ct` / `qt5ct` / Kvantum (`QT_QPA_PLATFORMTHEME=qt6ct`).
  - Optional `NOPASSWD` sudo rule for `tee /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode` enables passwordless Lenovo IdeaPad battery conservation toggling from Settings → Power (falls back to Polkit `pkexec` prompt otherwise).
  - Themes & fonts: `pop-icon-theme` (`QS_ICON_THEME=Pop`), `BreezeX-Black` cursor theme, `material-symbols`, `fira-sans`, and `noto-fonts-color-emoji` / `openmoji-color`.

## 6. Portals, KWallet & Secret Portal

- Configure `xdg.portal` (`xdgOpenUsePortal = true`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-cosmic` for `org.freedesktop.impl.portal.FileChooser`, and `org.freedesktop.impl.portal.Secret = kwallet`) so screen sharing, COSMIC file pickers, and Flatpak secret access work in Hyprland.
- Enable greeter/login PAM KWallet unlock (`security.pam.services.<greeter>.enableKwallet = true`) plus a Hyprland-only `pam_kwallet_init` systemd user service (`XDG_CURRENT_DESKTOP=Hyprland`) to unlock `kdewallet` at login.
