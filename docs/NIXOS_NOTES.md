# NixOS notes

**Implemented on 2026-10-24** in `~/Nix` branch `hypr-cosmic-shell` (commit 720714e):
`system/matevono/hyprland-desktop.nix` covers §1 (UWSM session), §2 (i2c), §5 (hyprlock PAM), the portal
Secret entry from §4, polkit-gnome outside Hyprland only, and every package/font/env var from this project's
flake. §3: rofi, waybar, wlogout, awww removed from `home/pkgs/default.nix`. Not applied to the running
system yet: see USER_GUIDE.md "Switching to the system install".

Follow-up commit bf622b4: UWSM runs XDG autostart entries, so `~/.config/autostart` overrides (via
Home Manager) hide polkit-gnome and nm-applet in Hyprland, and a user service runs `pam_kwallet_init`
so the wallet unlocks at login. Needs another `sudo nixos-rebuild switch --flake ~/Nix#matevono`.

The sections below are kept for reference. These are snippets for you to add to your own NixOS
configuration if and when you want them. The project itself runs without any of them.

## Capture, Screen Recorder, Privacy & Removable Storage (2026-10-25 00:30)

`system/matevono/hyprland-desktop.nix` adds `wf-recorder` and `wl-screenrec` alongside `grim`, `slurp`, and `swappy`.
`scripts/capture.sh` also auto-discovers `wf-recorder`, `wl-screenrec`, and `swappy` in `/nix/store` if not yet on `PATH`.
Removable drive automounting and safe ejection use `udevadm monitor` + `lsblk -J` + `udisksctl` (`services.udisks2` is active on the system).

## Quickshell apps & Bar Settings (2026-10-24 22:15)

Pure QML (`Launcher.qml`, `services/BarConfig.qml`, `bar/BarSettingsWindow.qml`, `bar/Bar.qml`, `components/Popup.qml`) plus floating window rules in `hypr/conf/windowrules.lua`; no extra Nix packages or rebuild needed. State is stored in Quickshell's state directory (`bar-config.json`).

## Power mode / TLP NOPASSWD rules (2026-10-24 21:48)

`system/matevono/configuration.nix` (commit 8e05413) adds `NOPASSWD` sudo rules for
`/run/current-system/sw/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference` (used by the
Balanced mode loop in `~/dotfiles/scripts/tlpmodes.sh`) and `/home/mate/dotfiles/scripts/tlpmodes.sh` itself, alongside
the existing `tlp` and `tee /sys/firmware/acpi/platform_profile` rules. Apply with `sudo nixos-rebuild switch --flake ~/Nix#matevono`.

## Calendar events helper (2026-10-24 21:40)

`system/matevono/calendar-events.nix` (imported from `hyprland-desktop.nix`) adds `hcs-calendar-events`: Python +
PyGObject with the Evolution Data Server, libical, glib, libxml2, libsoup and json-glib typelibs, running
`~/.config/quickshell/scripts/calendar-events.py`. The shell's calendar popup needs it on PATH:
**needs `sudo nixos-rebuild switch --flake ~/Nix#matevono`** (until then the popup shows cached data / "offline").
EDS itself (`evolution-data-server`) is already running via GNOME Calendar / the GNOME services.

## nm-applet in Hyprland (2026-10-24 21:15)

UWSM runs XDG autostart; `nm-applet.desktop` comes from `networkmanagerapplet`, which the COSMIC module installs
(`services.desktopManager.cosmic.enable`) and which only hides itself in KDE/GNOME/COSMIC. Hidden by hand with
`~/.config/autostart/nm-applet.desktop` (`Hidden=true`, not tracked in dotfiles). Declarative alternatives: the
Home Manager override from commit bf622b4 (add `Hyprland;` to `NotShowIn`), or
`environment.cosmic.excludePackages = [ pkgs.networkmanagerapplet ];` plus removing the `networkmanagerapplet`
line in `hyprland-desktop.nix` (not needed: the shell opens `cosmic-settings network`).

## 0. Plain vs UWSM session (2026-10-24 evening)

**Current choice (21:00): UWSM session** ("Hyprland (uwsm-managed)"). In `~/.config/hypr/conf/`:
`autostart.lua` and `environment.lua` have the manual environment/portal sync lines commented out (UWSM does
that), and `environment.lua` sets `TZDIR=/etc/zoneinfo` (needed in both session types). To use the plain
session again, uncomment those lines and start `graphical-session.target` (see below).

You can use either entry in the login screen; UWSM is not required.
- **"Hyprland (uwsm-managed)"** starts `graphical-session.target` by itself.
- **"Hyprland" (plain)**: Hyprland's autostart runs `~/.config/hypr/scripts/session-target.sh`, which starts
  `hyprland-session.target` (defined in `hyprland-desktop.nix`, commit 4e0f055; until that is rebuilt the script
  writes a runtime copy). That target pulls in `graphical-session.target`, so xdg-desktop-portal, `xdg-open`
  (`xdgOpenUsePortal = true`), screen sharing, polkit-gnome (outside Hyprland it is skipped) and the KWallet unlock
  service start as in the UWSM session. Without it, `xdg-open` fails with "Could not activate remote peer
  org.freedesktop.portal.Desktop".
- **`TZDIR` is dropped in both** (not by UWSM): NixOS' `programs.hyprland` installs Hyprland with a `cap_sys_nice`
  wrapper, glibc then removes `TZDIR`/`LD_LIBRARY_PATH` from Hyprland and its children. Fixed in the Hyprland
  config (`hl.env("TZDIR", "/etc/zoneinfo")`), nothing to do in Nix.

## 1. Hyprland as a login session (needed for portals: screen sharing, file pickers)

xdg-desktop-portal only starts while systemd's `graphical-session.target` is active. COSMIC starts
it for COSMIC sessions; a plain `Hyprland` session (from a TTY *or* from a greeter) doesn't. That's why
screen sharing didn't work (checked 2026-10-24: the portal failed with "Dependency failed").
With UWSM the session starts it properly:

```nix
programs.hyprland = {
  enable = true;
  withUWSM = true;    # "Hyprland (uwsm-managed)" session: starts graphical-session.target
};
```

To run this setup from that session, `~/.config/hypr/hyprland.lua` and `~/.config/quickshell` are symlinked from `~/dotfiles` (branch `hypr-cosmic-shell`).
In a plain non-UWSM session, `~/.config/hypr/scripts/session-target.sh start` makes the portal work for the current session.

## 2. External monitor brightness (Dell U2412M via DDC/CI)

```nix
hardware.i2c.enable = true;
users.users.mate.extraGroups = [ "i2c" ];
```

## 3. Packages you can remove after switching to this setup

Only do this once you start Hyprland with `hypr/hyprland.lua` for good: your original
`~/.config/hypr` config still calls these, and COSMIC doesn't need any of them.
They are currently in `users.users.mate.packages` (they show up in `/etc/profiles/per-user/mate/bin`).

| Package | Was used for | Replaced by |
|---|---|---|
| `rofi` | SUPER Space launcher, SUPER SHIFT C clipboard picker | shell launcher, shell clipboard popup |
| `waybar` | top bar | shell bar |
| `wlogout` | SUPER L session menu | shell power menu |
| `awww` | `swww.sh` wallpaper rotation | shell wallpaper slideshow |

```nix
users.users.mate.packages = with pkgs; [
  # remove: rofi waybar wlogout awww
];
```

Keep: `cliphist`, `wl-clipboard`, `hyprshot`, `hyprlock` (fallback lock), `playerctl`, `brightnessctl`.
The project's flake brings its own copies of everything the shell needs, so removing a global
package never breaks the shell.

Not installed at all (the original `autostart.conf` lines for them fail silently): `dunst`
(the shell is the notification daemon from milestone d) and `xembedsniproxy` (only needed for
old X11 tray icons; it's in `kdePackages.plasma-workspace` if you ever want it).

Old config folders that become unused: `~/.config/rofi`, `~/.config/waybar`, `~/.config/wlogout`,
`~/.config/dunst`, `~/.config/waypaper`. Nothing in this project reads them; delete them yourself when ready.

## 4. KWallet unlock at login

Already configured in `~/Nix/system/matevono/configuration.nix` (checked 2026-10-24):
`security.pam.services.cosmic-greeter.kwallet.enable` (+ `forceRun`) and
`security.pam.services.login.kwallet.enable`. Log in through cosmic-greeter and PAM unlocks the wallet.

Session side, for reference: PAM keeps the password until `pam_kwallet_init` (kwallet-pam) runs inside the
session and hands it to kwalletd. KDE/COSMIC run it from `/etc/xdg/autostart/pam_kwallet_init.desktop`;
plain Hyprland doesn't run XDG autostart entries. If the wallet still asks for its password in Hyprland,
`pam_kwallet_init` needs to be started from `hypr/conf/autostart.lua` (not done yet).

Flatpak apps ask for secrets through the portal; `~/.config/xdg-desktop-portal/hyprland-portals.conf` has no
Secret entry, so they fall back to gnome-keyring (disabled in your config). Optional line under `[preferred]`:
`org.freedesktop.impl.portal.Secret = kwallet`.

## 5. PAM service for hyprlock (to do later)

hyprlock authenticates through the PAM service `hyprlock`. Your system has no `/etc/pam.d/hyprlock`
(checked 2026-10-24), so hyprlock falls back to the `su` service. That still checks your password,
but it's not the intended setup. Add one of these:

```nix
security.pam.services.hyprlock = {};     # just the PAM service
# or
programs.hyprlock.enable = true;         # PAM service + hyprlock package
```

The project's hyprlock config (`hypr/hyprlock.conf`) doesn't need changing afterwards.

## Already fine (checked on 2026-10-24)

- `services.upower`: active
- `hardware.bluetooth` / bluetoothd: active
- NetworkManager: active
- PAM: not checked yet. Will be checked when the lock screen is built (milestone e).
