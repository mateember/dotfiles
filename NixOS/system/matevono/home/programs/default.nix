{
  config,
  pkgs,
  pkgs-unstable,
  hyprland,
  ...
}: {
  programs = {
    java.enable = true;
    java.package = pkgs-unstable.jdk;

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
    fish.enable = false;
  };

  home.packages =
    (with pkgs; [
      #dunst
      git-credential-oauth
      ranger
      glxinfo
      wlogout
      trash-cli
      qt6ct
      nwg-look
      pyenv
      ookla-speedtest
      arp-scan
    ])
    ++ (with pkgs-unstable; [
      vscode
      neovim
      fastfetch
      swww
      waybar
      distrobox
      wl-clipboard
      cliphist
      # hyprcursor
      arduino-ide

      #gnome
      gnomeExtensions.ddterm
      gnomeExtensions.desktop-icons-ng-ding
    ]);

  services.kdeconnect.enable = true;
}
