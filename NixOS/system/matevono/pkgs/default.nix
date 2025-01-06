{
  config,
  lib,
  pkgs,
  pkgs-unstable,
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
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
    };
    virt-manager.enable = true;
    # steam.extraCompatPackages = [pkgs.proton-ge-bin];
    xfconf.enable = true;
    dconf.enable = true;
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "ghostty";
    };
    nix-ld = {
      enable = true;
      #package = pkgs.nix-ld-rs;
      libraries = with pkgs; [
        SDL
        SDL2
        SDL2_image
        SDL2_mixer
        SDL2_ttf
        SDL_image
        SDL_mixer
        SDL_ttf
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
      usbutils
      acpi
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
      gnome-boxes
      qemu
      edid-decode
      gnome-tweaks
      nautilus-python
      vlc
      microsoft-edge
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      win-virtio
      win-spice
      gjs

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
    ])
    ++ (with pkgs-unstable; [
      ptyxis
      wl-clipboard-rs
      bat
      ghostty
      konsole
      #lact
      #kdePackages.polkit-kde-agent-1
      kdePackages.kirigami
      polkit_gnome
      kitty
      #alacritty
      github-desktop
      firefox
      tldr
      freerdp
      bc
      jetbrains-toolbox
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
