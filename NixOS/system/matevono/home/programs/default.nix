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
      glxinfo
      wlogout
      trash-cli
      nwg-look
      pyenv
      ookla-speedtest
      arp-scan
      nitch
      zen-browser.packages."${system}".default
      xorg.xkill
      xorg.xeyes
      #ghostty.packages."${system}".default
    ])
    ++ (with pkgs-unstable; [
      vscode
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
      rofi-wayland
      hyprshade
      hyprlock
      hypridle
      hyprshot
      swww
      hyprpaper
      waybar






      #gnome
      gnomeExtensions.ddterm
      gnomeExtensions.desktop-icons-ng-ding
    ]);

  services.kdeconnect.enable = true;
  services.blueman-applet.enable = false;
}
