#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$CONFIG_DIR"

# 1. Prune broken symlinks in ~/.config that pointed into this repo
while IFS= read -r -d '' link; do
    target="$(readlink "$link" || true)"
    if [[ "$target" == "$DOTFILES"/* ]]; then
        rm -f "$link"
        echo "Removed stale symlink: $link -> $target"
    fi
done < <(find "$CONFIG_DIR" -maxdepth 1 -type l ! -exec test -e {} \; -print0)

# 2. Link each directory in config/ into ~/.config/<name>
for src in "$DOTFILES/config"/*/; do
    [[ -d "$src" ]] || continue
    src="${src%/}"
    name="$(basename "$src")"
    dest="$CONFIG_DIR/$name"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        echo "Backed up existing directory: $dest -> $backup"
    fi

    ln -sfn "$src" "$dest"
    echo "Linked: $dest -> $src"
done

# 3. Link scripts/ to ~/.scripts
if [[ -e "$HOME/.scripts" && ! -L "$HOME/.scripts" ]]; then
    backup="$HOME/.scripts.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.scripts" "$backup"
    echo "Backed up existing directory: $HOME/.scripts -> $backup"
fi
ln -sfn "$DOTFILES/scripts" "$HOME/.scripts"
echo "Linked: $HOME/.scripts -> $DOTFILES/scripts"
