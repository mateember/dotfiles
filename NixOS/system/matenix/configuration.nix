{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  hyprland,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./pkgs
    ./extraconfig
  ];

  hardware = {
    bluetooth.enable = true; # enables support for Bluetooth
    bluetooth.powerOnBoot = true;
    bluetooth.settings.General.Experimental = true;

    sane = {
      enable = true;
      extraBackends = [pkgs.sane-airscan];
      openFirewall = true;
    };
    #  xone.enable = true;
    #  xpadneo.enable = true;

    /*
      opengl = {
      package = pkgs-unstable.mesa.drivers;

      # if you also want 32-bit support
      driSupport32Bit = true;
      package32 = pkgs-unstable.pkgsi686Linux.mesa.drivers;
    };
    */
  };

  #flake and nix setting
  nix = {
    settings = {
      auto-optimise-store = true;
      allowed-users = ["mate"];
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  #grub&boot
  boot = {
    consoleLogLevel = 3;

    kernelPackages = pkgs.linuxPackages_cachyos;
    extraModulePackages = with config.boot.kernelPackages; [xpadneo xone v4l2loopback];
    blacklistedKernelModules = ["xpad"];
    initrd.kernelModules = ["amdgpu"];
    kernelParams = ["amdgpu.ppfeaturemask=0xfff7ffff" "splash"];

    kernelModules = ["tcp_bbr" "v4l2loopback"];
    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
      "net.core.wmem_max" = 1073741824;
      "net.core.rmem_max" = 1073741824;
      "net.ipv4.tcp_rmem" = "4096 87380 1073741824";
      "net.ipv4.tcp_wmem" = "4096 87380 1073741824";
    };

    plymouth = {
      enable = true;
      theme = "darth_vader";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = ["darth_vader"];
        })
      ];
    };

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi"; # ← use the same mount point here.
      };

      grub = {
        useOSProber = true;
        efiSupport = true;
        device = "nodev";
        extraEntries = ''
           menuentry "Arch Linux TKG" --class archlinux{
             set root=(hd3,gpt1)  # Replace with the correct identifier if necessary
             linux /archroot/boot/vmlinuz-linux-tkg root=UUID=b69435d1-058f-42fa-87dc-64cd4b24f821 rw rootflags=subvol=/archroot amdgpu.ppfeaturemask=0xfff7ffff
             initrd /archroot/boot/initramfs-linux-tkg.img

           }

          menuentry "Arch Linux LTS" --class archlinux{
             set root=(hd3,gpt1)  # Replace with the correct identifier if necessary
             linux /archroot/boot/vmlinuz-linux-lts root=UUID=b69435d1-058f-42fa-87dc-64cd4b24f821 rw rootflags=subvol=/archroot amdgpu.ppfeaturemask=0xfff7ffff
             initrd /archroot/boot/initramfs-linux-lts.img

           }

        '';

        theme =
          pkgs.fetchFromGitHub
          {
            owner = "Coopydood";
            repo = "HyperFluent-GRUB-Theme";
            rev = "869b62584c1a05e711db72cb5a621538424d29f7";
            sha256 = "sha256-LGQahTnS6v23big5KC8LHS709zLXgp3QYcJ1lBTl2SM=";
          }
          + "/nixos";
      };
    };
  };

  #Networking
  networking.hostName = "matenix";
  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  systemd.network = {
    enable = false;

    networks."10-lan" = {
      matchConfig.Name = "enp7s0";
      networkConfig.DHCP = "yes";
      networkConfig.IPv6AcceptRA = true;
      networkConfig.DNS = "192.168.1.173";
      routes = [
        {
          InitialCongestionWindow = 30;
          InitialAdvertisedReceiveWindow = 70;
          #TCPCongestionControlAlgorithm = "bbr";
        }
      ];
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Time zone.
  time.timeZone = "Europe/Budapest";

  # Locale settings
  # Configure keymap in X11
  i18n.supportedLocales = [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "hu_HU.UTF-8/UTF-8"
  ];
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable CUPS to print documents.

  #Pipewire
  security.rtkit.enable = true;

  #User
  users.users.mate = {
    isNormalUser = true;
    extraGroups = [
      "flatpak"
      "disk"
      "qemu"
      "kvm"
      "libvirtd"
      "sshd"
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.fish;
  };

  # Services & SystemD

  systemd = {
    packages = with pkgs-unstable; [lact];

    services = {
      lactd = {
        enable = true; # this is true by default
        wantedBy = ["multi-user.target"]; # add this if you want the unit to auto start at boot time
      };

      "bingpaper" = {
        enable = true;
        description = "bingpaper";
        after = ["network-online.target"];
        wants = ["network-online.target"];

        script = ''/home/mate/.scripts/get-wallpaper.sh'';

        path = [pkgs.curl pkgs.libxml2];

        wantedBy = ["multi-user.target"];
      };
    };

    timers = {
      "bingpaper" = {
        description = "Get the Bing wallpaper";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = "*-*-* 06:00:00";
          Persistent = true;
          Unit = "bingpaper.service";
        };
      };
    };
  };

  services = {
    gnome.gnome-keyring.enable = true;
    flatpak.enable = true;
    #lactd.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    xserver.xkb.layout = "hu";

    # Plasma, SDDM
    xserver.enable = true;
    desktopManager.plasma6.enable = true;
    displayManager = {
      sessionPackages = [hyprland.packages.${pkgs.system}.hyprland];
      sddm.enable = true;
      defaultSession = "hyprland";
      sddm.theme = "sddm-theme-bluish";
      sddm.wayland.enable = true;

      autoLogin = {
        enable = false;
        user = "mate";
      };
    };

    blueman.enable = true;

    gvfs.enable = true;
    tumbler.enable = true;

    tailscale.enable = true;
    tailscale.useRoutingFeatures = "client";
    #openssh.enable = true;

    printing.enable = true;
    printing.drivers = [pkgs.epson-escpr];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [24642];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };

  virtualisation = {
    libvirtd.enable = true;
    containers.enable = true;
    podman = {
      enable = false;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };

    docker = {
      enable = true;
      daemon.settings = {
        #ipv6 = true;
      };
    };
  };

  xdg = {
    menus.enable = true;
    portal = {
      xdgOpenUsePortal = true;
      enable = true;
      config.common.default = "gnome";
      extraPortals = [pkgs-unstable.kdePackages.xdg-desktop-portal-kde pkgs-unstable.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland];
    };
  };
  #Sudo
  security = {
    pam.services.mate.enableGnomeKeyring = true;
    sudo = {
      enable = true;
      extraRules = [
        {
          commands = [
            {
              command = "${pkgs.systemd}/bin/systemctl suspend";
              options = ["NOPASSWD"];
            }
            {
              command = "${pkgs.systemd}/bin/reboot";
              options = ["NOPASSWD"];
            }
            {
              command = "${pkgs.systemd}/bin/poweroff";
              options = ["NOPASSWD"];
            }
            {
              command = "/run/current-system/sw/bin/lact";
              options = ["NOPASSWD"];
            }
          ];
          users = ["mate"];
        }
      ];
      extraConfig = with pkgs; ''
        Defaults:picloud secure_path="${lib.makeBinPath [
          systemd
        ]}:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      '';
    };
  };

  fonts = {
    packages = with pkgs; [
      jetbrains-mono
      fira-code
      roboto
      openmoji-color
      (nerdfonts.override {fonts = ["JetBrainsMono" "FiraCode"];})
    ];

    fontconfig = {
      hinting.autohint = true;
      defaultFonts = {
        emoji = ["OpenMoji Color"];
      };
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
