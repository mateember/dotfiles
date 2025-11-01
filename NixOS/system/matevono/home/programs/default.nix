{
  config,
  pkgs,
  pkgs-unstable,
  hyprland,
  zen-browser,
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
      mesa-demos
      wlogout
      trash-cli
      nwg-look
      pyenv
      ookla-speedtest
      arp-scan
      nitch
      xorg.xkill
      xorg.xeyes
      #ghostty.packages."${system}".default
    ])
    ++ (with pkgs-unstable; [
      vscode-fhs
      zed-editor-fhs
      hpp2plantuml
      plantuml
      sunshine
      uxplay
      brave
      neovim
      celluloid
      openboard
      fastfetch
      distrobox
      wl-clipboard
      brightnessctl
      cliphist
      arduino-ide
      python3
      zellij
      foot
      alacritty
      # nwg-panel

      #Hyprland Stuff
      hyprcursor
      # waypaper
      rofi
      hyprshade
      hyprlock
      hypridle
      hyprshot
      swww
      hyprpaper
      waybar

      #gnome
      gnomeExtensions.ddterm
      gnomeExtensions.gsconnect
      gnomeExtensions.desktop-icons-ng-ding
    ]);

  # services.kdeconnect.enable = true;
  services.blueman-applet.enable = false;
}
