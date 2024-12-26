alias rm="trash"
alias vim="nvim"
alias code="env GTK_THEME=adw-gtk3-dark code"
alias openboard="openboard -lang hu"
alias vencord='sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"'
alias upd="yay ; flatpak update"
alias nixrbd="sudo nixos-rebuild switch --flake ~/dotfiles/NixOS"
alias nixupd="sudo nix flake update --flake ~/dotfiles/NixOS; sudo nixos-rebuild switch --flake ~/dotfiles/NixOS"
alias nixgb="sudo nix-collect-garbage -d"
alias uxplay="uxplay -fps 75 -n PC -avdec -async -vsync no"
alias neofetch="fastfetch -c ~/.config/fastfetch/custom.jsonc"
alias cat="bat"
alias yay="paru"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
