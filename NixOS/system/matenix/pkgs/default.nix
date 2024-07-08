{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  hyprland,
  ...
}: {
  nixpkgs.overlays = [
  ];

  #Chaotic AUR
  chaotic.mesa-git.enable = true;
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

      (callPackage ./sddm-bluish {}).sddm-bluish
      (callPackage ./sddm-sugarcandy {}).sddm-sugarcandy

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
    ]);
}
