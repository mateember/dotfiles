{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  hyprland,
  winapps,
  ...
}: {
  #Chaotic AUR
  chaotic.mesa-git.enable = false;
  chaotic.mesa-git.fallbackSpecialisation = false;

  programs = {
    fish.enable = true;
    zsh.enable = true;
    fuse.userAllowOther = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
    };
    nm-applet.enable = false;
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
      # package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      # portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };
    virt-manager.enable = true;
    # steam.extraCompatPackages = [pkgs.proton-ge-bin];
    xfconf.enable = false;
    dconf.enable = true;
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        SDL
        SDL2
        SDL2_image
        SDL2_mixer
        SDL2_ttf
        SDL_image
        SDL_mixer
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        bzip2
        cairo
        cups
        curlWithGnuTls
        dbus
        dbus-glib
        desktop-file-utils
        e2fsprogs
        expat
        flac
        fontconfig
        freeglut
        freetype
        fribidi
        fuse
        fuse3
        gdk-pixbuf
        glew110
        glib
        gmp
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-ugly
        gst_all_1.gstreamer
        gtk2
        harfbuzz
        icu
        keyutils.lib
        libGL
        libGLU
        libappindicator-gtk2
        libcaca
        libcanberra
        libcap
        libclang.lib
        libdbusmenu
        libdrm
        libgcrypt
        libgpg-error
        libidn
        libjack2
        libjpeg
        libmikmod
        libogg
        libpng12
        libpulseaudio
        librsvg
        libsamplerate
        libthai
        libtheora
        libtiff
        libudev0-shim
        libusb1
        libuuid
        libvdpau
        libvorbis
        libvpx
        libxcrypt-legacy
        libxkbcommon
        libxml2
        mesa
        nspr
        nss
        openssl
        p11-kit
        pango
        pixman
        python3
        speex
        stdenv.cc.cc
        tbb
        udev
        vulkan-loader
        wayland
        xorg.libICE
        xorg.libSM
        xorg.libX11
        xorg.libXScrnSaver
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXft
        xorg.libXi
        xorg.libXinerama
        xorg.libXmu
        xorg.libXrandr
        xorg.libXrender
        xorg.libXt
        xorg.libXtst
        xorg.libXxf86vm
        xorg.libpciaccess
        xorg.libxcb
        xorg.xcbutil
        xorg.xcbutilimage
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilwm
        xorg.xkeyboardconfig
        xz
        zlib
      ];
    };
  };

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
      starship
      zoxide
      kdePackages.qtstyleplugin-kvantum
      kdePackages.kdecoration
      fuse
      sshfs-fuse
      killall
      btop
      usbutils
      acpi
      lm_sensors
      fzf
      podman-tui
      dive
      efibootmgr
      podman-compose
      kdePackages.extra-cmake-modules
      uv
      pavucontrol
      kdePackages.dolphin
      nautilus
      appimage-run
      evince
      alsa-utils
      dig
      playerctl
      pamixer
      which
      v4l-utils
      icu
      gnome-boxes
      qemu
      rclone
      edid-decode
      gnome-tweaks
      nautilus-python
      winapps.packages."${system}".winapps
      winapps.packages."${system}".winapps-launcher # optional
      vlc
      microsoft-edge
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      win-virtio
      win-spice
      gjs
      ripgrep
      libsixel
      fd
      (callPackage ./sddm-bluish {}).sddm-bluish
      #(callPackage ./sddm-sugarcandy {}).sddm-sugarcandy

      #Development packages
      file
      github-desktop
      valgrind
      llvm
      clang
      unzip
      gdb
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

     #Default
      sox
      tcc
      netcat-openbsd
      rtl-sdr
      gnuradio

    ])
    ++ (with pkgs-unstable; [
      wl-clipboard-rs
      bat
      ghostty
      kdePackages.konsole
      kdePackages.okular
      #lact
      #kdePackages.polkit-kde-agent-1
      kdePackages.kirigami
      davinci-resolve
      polkit_gnome
      kitty
      mangohud
      #alacritty
      github-desktop
      firefox
      brave
      tldr
      freerdp3
      bc
      geekbench
      jetbrains.clion
      jetbrains.pycharm-professional
      qt6ct
    ]);

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-console
    gnome-connections
    epiphany # web browser
    geary # email reader. Up to 24.05. Starting from 24.11 the package name is just geary.
    evince # document viewer
  ];
}
