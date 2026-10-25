#!/usr/bin/env bash
# Start systemd's graphical-session.target for a plain (non-UWSM) Hyprland session.
#
# xdg-desktop-portal (xdg-open with xdgOpenUsePortal, screen sharing, file pickers, ...) and every
# service that is wantedBy graphical-session.target only run while that target is active.
# UWSM starts it; a plain "Hyprland" session from the display manager doesn't, and
# `systemctl --user start graphical-session.target` is refused (RefuseManualStart), so a small
# target that BindsTo it does the job.
#
# The target comes from the NixOS config (hyprland-desktop.nix: systemd.user.targets.hyprland-session).
# Until that is rebuilt, a runtime copy is written to $XDG_RUNTIME_DIR (gone after logout).
#
#   session-target.sh start    (hypr/conf/autostart.lua, at Hyprland start)
#   session-target.sh stop     (when Hyprland shuts down)
set -u
UNIT=hyprland-session.target

case "${1:-start}" in
  start)
    # Services started by systemd / D-Bus activation must see this session's display and desktop.
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
      XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORMTHEME \
      XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE TZDIR 2>/dev/null
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP \
      XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE 2>/dev/null

    if ! systemctl --user cat "$UNIT" >/dev/null 2>&1; then
      dir="${XDG_RUNTIME_DIR:?}/systemd/user"
      mkdir -p "$dir"
      cat > "$dir/$UNIT" <<'EOF'
[Unit]
Description=Hyprland session (runtime copy)
BindsTo=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
EOF
      systemctl --user daemon-reload
    fi

    systemctl --user start "$UNIT"
    # Portals that already started (or failed) before the display variables were available.
    systemctl --user try-restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service 2>/dev/null
    ;;
  stop)
    systemctl --user stop "$UNIT"
    ;;
esac
exit 0
