# NixOS System Notes

System-level NixOS configuration required by this dotfiles setup (configured in `~/Nix`).

## 1. Hyprland UWSM Session & `TZDIR`

Enable Hyprland with UWSM so `graphical-session.target` starts and `xdg-desktop-portal` (screen sharing, file pickers, `xdg-open`) works properly:

```nix
programs.hyprland = {
  enable = true;
  withUWSM = true;
};
```

- Because NixOS wraps `Hyprland` with `cap_sys_nice`, glibc strips `TZDIR` from its environment. [`config/hypr/conf/environment.lua`](file:///home/mate/dotfiles/config/hypr/conf/environment.lua) restores `TZDIR=/etc/zoneinfo` for child processes.
- `hypridle` runs as a systemd user service (`services.hypridle`) rather than from `autostart.lua`.
- UWSM runs XDG autostart entries; hide `nm-applet` and `polkit-gnome` in Hyprland (`NotShowIn=Hyprland;` or `~/.config/autostart/*.desktop` with `Hidden=true`) so they do not conflict with Quickshell's Network widget and Polkit agent.

## 2. Lock Screen PAM Services & Howdy

[`LockScreen.qml`](file:///home/mate/dotfiles/config/quickshell/lock/LockScreen.qml) runs two parallel `PamContext` conversations:
- `qs-lock`: pure `pam_unix` password authentication (unlocks immediately without waiting on biometric timeouts).
- `qs-lock-face`: Howdy IR facial recognition (`pam_howdy.so`) when Howdy is installed, enabled, the camera exists, and the user has an enrolled model.

Both PAM services must be defined under `security.pam.services` in the NixOS configuration.

## 3. External Monitor Brightness (DDC/CI)

Required by the Display widget's external monitor slider:

```nix
hardware.i2c.enable = true;
users.users.mate.extraGroups = [ "i2c" ];
```

## 4. Power Mode (`tlpmodes.sh`) Sudo Rules

Quickshell's `PowerProfile` service and [`scripts/tlpmodes.sh`](file:///home/mate/dotfiles/scripts/tlpmodes.sh) require `NOPASSWD` sudo rules for:
- `tlp`
- `tee /sys/firmware/acpi/platform_profile`
- `tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`
- `/home/mate/dotfiles/scripts/tlpmodes.sh`

## 5. Desktop Shell Dependencies

- **Calendar Events**: `hcs-calendar-events` wrapper providing Python + PyGObject with `EDataServer-1.2`, `ECal-2.0`, `ICalGLib-3.0`, GLib, libxml2, libsoup, and json-glib typelibs to run [`config/quickshell/scripts/calendar-events.py`](file:///home/mate/dotfiles/config/quickshell/scripts/calendar-events.py) against `evolution-data-server`.
- **Emoji Picker**: `HCS_EMOJI_FILE` environment variable pointing to Unicode's `emoji-test.txt`, plus `wtype` and `wl-clipboard`.
- **Capture & Recording**: `grim`, `slurp`, `swappy`, `wf-recorder` / `wl-screenrec`, `hyprshot`, `hyprpicker`.
- **Removable Storage**: `services.udisks2.enable = true` (`udisksctl`, `lsblk`, `udevadm`).
- **Background Selector & Animated Loops**: `zenity` (native folder/media pickers), `ffmpeg` (converts `.webp` images and short video clips into cached looping GIFs), and `qt6.qtshadertools` (`qsb`, only needed when recompiling [GLSL fragment shaders](file:///home/mate/dotfiles/config/quickshell/wallpaper/shaders/compile.sh)).
- **System Controls & Icons**: `hyprsunset`, `brightnessctl`, `ddcutil`, `playerctl`, `cliphist`, `libqalculate` (`qalc`), `pavucontrol`, `networkmanagerapplet`, `gnome-calendar`, `kdePackages.kdeconnect-kde`, `pop-icon-theme`, and fonts (`material-symbols`, `fira-sans`, `noto-fonts-color-emoji`).

## 6. KWallet & Secret Portal

- Greeter/login PAM KWallet unlock (`security.pam.services.<greeter>.kwallet.enable`) plus a Hyprland-only `pam_kwallet_init` user service unlocks `kdewallet` at login.
- Set `org.freedesktop.impl.portal.Secret = kwallet` in `xdg.portal.config.hyprland` so Flatpak and portal-aware apps read secrets from KWallet.
