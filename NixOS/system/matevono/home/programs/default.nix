{
  config,
  pkgs,
  pkgs-unstable,
  hyprland,
  zen-browser,
  hyprdynamicmonitors,
  hyprshutdown,
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
