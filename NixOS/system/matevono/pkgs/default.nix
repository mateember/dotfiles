{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  hyprland,
  winapps,
  inputs,
  ...
}: {
  disabledModules = ["programs/wayland/hyprland.nix"];

  imports = [
    # ./overlays/howdy.nix
    "${inputs.nixpkgs-unstable}/nixos/modules/programs/wayland/hyprland.nix"
    ./nixld.nix
  ];

  nixpkgs.config.allowInsecurePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "ventoy"
    ];

  #Chaotic AUR
  chaotic.mesa-git.enable = false;
  chaotic.mesa-git.fallbackSpecialisation = false;

  programs = {
    fish.enable = true;
    fish.package = pkgs-unstable.fish;
    zsh.enable = true;
    fuse.userAllowOther = true;
    niri = {
      package = pkgs-unstable.niri;
      enable = true;
      useNautilus = true;
    };
    gtklock = {
      enable = true;
      modules = with pkgs-unstable; [gtklock-playerctl-module gtklock-powerbar-module];
      package = pkgs-unstable.gtklock;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
    };
    nm-applet.enable = false;
    hyprland = {
      enable = false;
      xwayland.enable = true;
      # package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      # portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      package = pkgs-unstable.hyprland;
      portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
    };
    virt-manager.enable = true;
    # steam.extraCompatPackages = [pkgs.proton-ge-bin];
    xfconf.enable = true;
    dconf.enable = true;
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };
    thunar = {
      enable = true;
      plugins = with pkgs-unstable; [thunar-archive-plugin thunar-vcs-plugin thunar-media-tags-plugin];
    };
    adb.enable = true;
  };

  stylix.enable = false;
  # System packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages =
    (with pkgs; [
      vim
      libnotify
      wget
      snixembed
      nano
      tree
      android-tools
      gfortran
      starship
      polkit_gnome
      zoxide
      kdePackages.qtstyleplugin-kvantum
      kdePackages.kdecoration
      fuse
      sshfs-fuse
      killall
      pciutils
      btop
      kdePackages.plasma-integration
      usbutils
      acpi
      lm_sensors
      fzf
      (octaveFull.withPackages (opkgs: with opkgs; [symbolic control io signal]))
      podman-tui
      ddcutil
      rar
      dive
      efibootmgr
      podman-compose
      ventoy
      kdePackages.extra-cmake-modules
      uv
      pavucontrol
      kdePackages.dolphin
      kdePackages.kwalletmanager
      nautilus
      appimage-run
      evince
      alsa-utils
      dig
      playerctl
      pamixer
      which
      lsof
      lshw
      dmidecode
      taler-sync
      v4l-utils
      libva-utils
      icu
      jellyfin-ffmpeg
      gnome-boxes
      qemu
      rclone
      edid-decode
      gnome-tweaks
      texliveTeTeX
      nautilus-python
      winapps.packages."${system}".winapps
      winapps.packages."${system}".winapps-launcher # optional
      vlc
      virt-viewer
      spice
      mutter
      spice-gtk
      spice-protocol
      virtio-win
      win-spice
      gjs
      ripgrep
      libsixel
      fd
      (callPackage ./sddm-bluish {}).sddm-bluish
      #(callPackage ./sddm-sugarcandy {}).sddm-sugarcandy
      sddm-sugar-dark
      kdePackages.sddm
      kdePackages.sddm-kcm

      #Development packages
      file
      github-desktop
      valgrind
      llvm
      xterm
      clang
      unzip
      gdb
      git
      lazygit
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
      man-pages
      man-pages-posix

      #Default
      sox
      tinycc
      netcat-openbsd
      rtl-sdr
      gnuradio
    ])
    ++ (with pkgs-unstable; [
      wl-clipboard-rs
      bat
      libimobiledevice
      idevicerestore
      ifuse
      ghostty
      xwayland-satellite
      kdePackages.konsole
      kdePackages.okular
      #lact
      #kdePackages.polkit-kde-agent-1
      kdePackages.kirigami
      kitty
      mangohud
      #alacritty
      github-desktop
      firefox
      tldr
      freerdp
      bc
      geekbench
      # jetbrains.clion
      # jetbrains.pycharm-professional
      qt6Packages.qt6ct
    ]);

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-console
    gnome-connections
    epiphany # web browser
    geary # email reader. Up to 24.05. Starting from 24.11 the package name is just geary.
    evince # document viewer
  ];
  documentation.dev.enable = true;
}
