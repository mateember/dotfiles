{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  hyprland,
  zen-browser,
  ...
}: {
  nixpkgs.overlays = [
  ];

  #Chaotic AUR
  chaotic.mesa-git.enable = false;
  chaotic.mesa-git.fallbackSpecialisation = false;

  programs = {
    fish.enable = true;
    zsh.enable = true;
    steam.enable = true;
    xfconf.enable = true;
    dconf.enable = true;
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;
    };
  };

  # System packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages =
    (with pkgs; [
      vim
      wget
      nano
      tree
      starship
      zoxide
      kdePackages.qtstyleplugin-kvantum
      kdePackages.kdecoration
      fuse
      sshfs-fuse
      killall
      btop
      fzf
      podman-tui
      dive
      podman-compose
      kdePackages.extra-cmake-modules
      pavucontrol
      appimage-run
      alsa-utils
      playerctl
      pamixer
      which
      networkmanagerapplet
      v4l-utils
      icu
      gnome-terminal
      zen-browser.packages."${system}".specific
      edid-decode
      gnome-tweaks
      vlc

      #(callPackage ./sddm-bluish {}).sddm-bluish
      #(callPackage ./sddm-sugarcandy {}).sddm-sugarcandy

      #Development packages
      github-desktop
      llvm
      clang
      git
      cmake
      gcc
      gnumake
      flex
      bison
      lld
      elfutils
      nix-prefetch-git
      curl
      libxml2
    ])
    ++ (with pkgs-unstable; [
      bat
      lact
      kdePackages.polkit-kde-agent-1
      kdePackages.kirigami
      polkit_gnome
      kitty
      alacritty
      github-desktop
      firefox
      tldr
      jetbrains-toolbox
    ]);

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany # web browser
    geary # email reader. Up to 24.05. Starting from 24.11 the package name is just geary.
    evince # document viewer
  ];
}
