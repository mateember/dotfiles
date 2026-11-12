# dotfiles

Personal NixOS dotfiles featuring a Lua-configured **Hyprland** compositor and a COSMIC Dark-themed **Quickshell** desktop environment, along with shell, editor, terminal, and Qt theming configurations.

*(Historical note: Niri was used for a short time before moving to Hyprland's built-in scrolling layout.)*

## Installation

Run [`link.sh`](file:///home/mate/dotfiles/link.sh) to symlink everything into place:

```bash
./link.sh
```

- Symlinks each directory under [`config/`](file:///home/mate/dotfiles/config) to `~/.config/<name>`
- Symlinks [`scripts/`](file:///home/mate/dotfiles/scripts) to `~/.scripts`
- Prunes broken symlinks in `~/.config` that previously pointed into this repo, and backs up existing non-symlink directories with a timestamped `.bak` suffix

## What's Inside

- **Desktop Environment** ([`config/hypr/`](file:///home/mate/dotfiles/config/hypr), [`config/quickshell/`](file:///home/mate/dotfiles/config/quickshell)):
  - Hyprland (Lua config) with scrolling layout, touchpad gestures, dynamic `SUPER+F` column width toggling, and window/layer rules
  - Quickshell desktop shell with a 21-widget customizable top bar, app launcher (`=`, `>`, `:`, `!`), Overview, Quick Settings, Capture & Screen Recording studio, notification center & OSDs, polkit prompt, Bing wallpaper slideshow, and a separate-process Wayland lock screen (password + Howdy IR)
- **Shell, Terminal & Editor**:
  - [`config/fish/`](file:///home/mate/dotfiles/config/fish) — Fish shell with Starship/Zoxide, NixOS & utility aliases, and helper functions
  - [`config/kitty/`](file:///home/mate/dotfiles/config/kitty) — Kitty terminal configuration
  - [`config/nvim/`](file:///home/mate/dotfiles/config/nvim) — Neovim configuration (Lazy.nvim)
- **Theming & Tools**:
  - [`config/qt5ct/`](file:///home/mate/dotfiles/config/qt5ct), [`config/qt6ct/`](file:///home/mate/dotfiles/config/qt6ct), [`config/Kvantum/`](file:///home/mate/dotfiles/config/Kvantum) — COSMIC Dark Qt/KDE styling and [`make-cosmic-shell-theme.py`](file:///home/mate/dotfiles/config/qt6ct/make-cosmic-shell-theme.py) generator
  - [`config/fastfetch/`](file:///home/mate/dotfiles/config/fastfetch), [`config/distrobox/`](file:///home/mate/dotfiles/config/distrobox), [`config/winapps/`](file:///home/mate/dotfiles/config/winapps)
  - [`scripts/`](file:///home/mate/dotfiles/scripts) — Power profile switcher (`tlpmodes.sh`), Bing wallpaper fetcher (`bingpaper.sh`), and Sunshine virtual monitor (`sunshine.sh`)

## Documentation

- [`docs/USER_GUIDE.md`](file:///home/mate/dotfiles/docs/USER_GUIDE.md) — Keybindings, bar widgets, launcher modes, IPC commands, scripts, and file reference
- [`docs/NIXOS_NOTES.md`](file:///home/mate/dotfiles/docs/NIXOS_NOTES.md) — NixOS packages, PAM services, UWSM session, and sudo rules required by this setup
- [`AGENTS.md`](file:///home/mate/dotfiles/AGENTS.md) — Agent instructions, coding conventions, and architecture notes
