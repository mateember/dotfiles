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
      dunst

      git-credential-oauth
      ranger
      glxinfo
      blueman
      wlogout
      trash-cli
      qt5ct
      qt6ct
      nwg-look
      pyenv
      ookla-speedtest
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
      jetbrains-toolbox
      arduino-ide
    ]);

  services.kdeconnect.enable = true;
}
