{
  config,
  pkgs,
  pkgs-unstable,
  hyprland,
  zen-browser,
  hyprdynamicmonitors,
  hyprshutdown,
  astal,
  ...
}: {
  programs = {
    java.enable = true;
    java.package = pkgs-unstable.jdk;
    ags = {
      enable = true;
    # configDir = ../../../../config/ags;

      extraPackages = let
        # Create a shorthand for the astal libraries
        astalPkgs = astal.packages.${pkgs.system};
      in [
        # 1. Add the Astal Libraries individually
        astalPkgs.astal3
        astalPkgs.io
        astalPkgs.astal4
        astalPkgs.hyprland
        astalPkgs.wireplumber
        astalPkgs.battery
        astalPkgs.network
        astalPkgs.mpris
        astalPkgs.notifd

        # 2. Add normal packages using the standard pkgs prefix
        # (This is much safer than 'with pkgs;' when troubleshooting)
        pkgs.fzf
        pkgs.brightnessctl
        pkgs.libnotify
        pkgs.jq
        pkgs.curl
      ];
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
    fish.enable = false;
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
      enableZshIntegration = true; # Optional, if you use Zsh sometimes
      enableFishIntegration = true; # This is TRUE by default if fish is enabled
    };
  };

  home.packages =
    (with pkgs; [
      dunst
      git-credential-oauth
      ranger
      mesa-demos
      hyprdynamicmonitors.packages.${system}.default
      wlogout
      trash-cli
      pwvucontrol
      zenity
      nwg-look
      pyenv
      wtype
      ookla-speedtest
      arp-scan
      nitch
      jq
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
      rofi
      hyprsunset
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

  services.kdeconnect.enable = true;
  services.blueman-applet.enable = false;
}
