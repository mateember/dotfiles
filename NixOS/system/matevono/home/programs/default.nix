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
      hyprshot
      fastfetch
      swww
      waybar
      distrobox
      wl-clipboard
      brightnessctl
      cliphist
      hyprcursor
      arduino-ide
      python3
      zellij
      foot
      alacritty
      rofi-wayland
      waypaper
      nwg-panel

      #gnome
      gnomeExtensions.ddterm
      gnomeExtensions.desktop-icons-ng-ding
    ]);

  services.kdeconnect.enable = true;
  services.blueman-applet.enable = false;
}
