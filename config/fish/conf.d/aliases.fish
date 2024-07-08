alias rm="trash"
alias vim="nvim"
alias code="env GTK_THEME=adw-gtk3-dark code"
alias openboard="openboard -lang hu"
alias vencord='sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"'
alias upd="yay ; flatpak update"
alias nixrbd="sudo nixos-rebuild switch --flake ~/dotfiles/Hyprland-NixOS"
alias nixupd="sudo nix flake update ~/dotfiles/Hyprland-NixOS; sudo nixos-rebuild switch --flake ~/dotfiles/Hyprland-NixOS"
alias uxplay="uxplay -fps 75 -n PC -avdec -async -vsync no"
alias neofetch="fastfetch -c ~/.config/fastfetch/ctt.jsonc"
alias cat="bat"
alias yay="paru"
alias vpnd="sudo tailscale down"
alias vpnu="sudo tailscale up"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"