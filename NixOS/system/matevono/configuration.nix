{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  # nixos-cosmic,
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
    firmware = [
      pkgs.sof-firmware
      (
        pkgs.runCommand "customedid.bin" {compressFirmware = false;} ''
           mkdir -p $out/lib/firmware/edid
          cp "${./firmware/customedid.bin}" $out/lib/firmware/edid/customedid.bin
        ''
      )
    ];
    #  xone.enable = true;
    #  xpadneo.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-compute-runtime
        vpl-gpu-rt
        libvdpau-va-gl
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };
  #flake and nix setting
  nix = {
    settings = {
      auto-optimise-store = true;
      allowed-users = ["mate"];
      substituters = ["https://cosmic.cachix.org/" "https://hyprland.cachix.org" "https://winapps.cachix.org/"];
      trusted-public-keys = ["cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "winapps.cachix.org-1:HI82jWrXZsQRar/PChgIx1unmuEsiQMQq+zt05CD36g="];
      download-buffer-size = 1024288000;
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

    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = with config.boot.kernelPackages; [xone v4l2loopback xpadneo acpi_call];
    blacklistedKernelModules = ["xpad"];
    initrd.kernelModules = [];
    kernelParams = ["splash" "drm.edid_firmware=eDP-1:edid/customedid.bin" "drm_kms_helper.edid_firmware=eDP-1:edid/customedid.bin" "video=eDP-1:e"];

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

    /*
      initrd.extraFiles."/lib/firmware/edid/customedid.bin".source = (
      pkgs.runCommand "customedid.bin" {} ''
        mkdir -p $out/lib/firmware/edid
        cp ${./firmware/customedid.bin} $out/lib/firmware/edid/customedid.bin
      ''
    );
    */

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/"; # ← use the same mount point here.
      };

      grub = {
        useOSProber = true;
        efiSupport = true;
        device = "nodev";

        theme =
          pkgs.fetchFromGitHub
          {
            owner = "Coopydood";
            repo = "HyperFluent-GRUB-Theme";
            rev = "62e525ea2aa250e3f37669d68eb355b6cc997d64";
            sha256 = "sha256-Als4Tp6VwzwHjUyC62mYyiej1pZL9Tzj4uhTRoL+U9Q=";
          }
          + "/nixos";
        /*
          extraEntries = ''
           menuentry "Arch Linux" --class archlinux{
             set root=(hd0,gpt1)  # Replace with the correct identifier if necessary
             linux /vmlinuz-linux root=UUID=487332e4-403c-4418-9717-3fe5a0eea16f rw rootflags=subvol=/archroot "drm.edid_firmware=DP-1:edid/custom.bin"
             initrd /initramfs-linux.img

           }

          menuentry "Arch Linux LTS" --class archlinux{
             set root=(hd3,gpt1)  # Replace with the correct identifier if necessary
             linux /vmlinuz-linux-lts root=UUID=487332e4-403c-4418-9717-3fe5a0eea16f rw rootflags=subvol=/archroot "drm.edid_firmware=DP-1:edid/custom.bin"
             initrd /initramfs-linux-lts.img

           }

        '';
        */
      };
    };
  };

  #Networking

  networking = {
    useDHCP = false;
    hostName = "matevono";
    networkmanager = {
      enable = true;

      plugins = [pkgs.networkmanager-strongswan];
    };
  };

  systemd = {
    services = {
      gnome-remote-desktop.wantedBy = ["graphical.target"];
    };

    user.services = {
    };
    network = {
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

  #User
  users = {
    groups.libvirtd.members = ["root"];
    groups.mate = {
      name = "mate";
      gid = 1000;
    };

    users.mate = {
      isNormalUser = true;
      extraGroups = [
        "mate"
        "flatpak"
        "disk"
        "qemu"
        "kvm"
        "libvirtd"
        "fuse"
        "i2c"
        "sshd"
        "users"
        "networkmanager"
        "wheel"
        "audio"
        "video"
        "libvirtd"
        "libvirt"
        "docker"
        "podman"
        "plugdev"
      ];
      shell = pkgs.fish;
    };
  };

  # Services & SystemD

  services = {
    pulseaudio.enable = false;
    ddccontrol.enable = true;
    power-profiles-daemon.enable = false;
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        MEM_SLEEP_ON_AC = "s2idle";
        MEM_SLEEP_ON_BAT = "s2idle";
        PCIE_ASPM_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersave";
        SOUND_POWER_SAVE_ON_AC = "0";

        #Optional helps save long term battery health
        #START_CHARGE_THRESH_BAT0 = 40; # 40 and bellow it starts to charge
        # STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
      };
    };

    gnome = {
      gnome-keyring.enable = true;
      gnome-browser-connector.enable = true;
      gnome-remote-desktop.enable = true;
    };

    xrdp = {
      enable = false;
      openFirewall = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
    };

    flatpak.enable = true;
    #lactd.enable = true;

    strongswan = {
      enable = true;
    };

    #strongswan-swanctl.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      extraConfig.pipewire = {
        "default.clock.quantum" = 32;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 32;
      };
    };

    xserver.xkb.layout = "hu";

    # Plasma, SDDM
    xserver = {
      enable = true;
    };
    desktopManager.plasma6.enable = false;
    desktopManager.gnome.enable = true;
    desktopManager.cosmic.enable = true;
    displayManager = {
      #sessionPackages = [hyprland.packages.${pkgs.system}.hyprland];
      sddm.enable = false;
      gdm.enable = true;

      cosmic-greeter.enable = false;

      #defaultSession = "";
      sddm.theme = "sddm-theme-bluish";
      sddm.wayland.enable = true;

      autoLogin = {
        enable = false;
        user = "mate";
      };
    };

    getty.autologinUser = null;

    blueman.enable = true;

    gvfs.enable = true;
    tumbler.enable = true;

    tailscale.enable = true;
    tailscale.useRoutingFeatures = "both";
    tailscale.openFirewall = true;
    #openssh.enable = true;

    printing.enable = true;
    printing.drivers = [pkgs.epson-escpr];

    avahi.publish.enable = true;
    avahi.publish.userServices = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [24642];
    allowedTCPPorts = [47984 47989 47990 48010 3389];

    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
      {
        from = 47998;
        to = 48000;
      }
    ];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    trustedInterfaces = ["virbr0" "vnet3"];
  };

  environment = {
    variables = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      EDITOR = "nvim";
    };
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        vhostUserPackages = [pkgs.virtiofsd];
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
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
      storageDriver = "btrfs";
      daemon.settings = {
        #ipv6 = true;
      };
    };
  };

  xdg = {
    menus.enable = true;
    # autostart.enable = false;
    portal = {
      xdgOpenUsePortal = true;
      enable = true;
      #config.common.default = "gnome";
      extraPortals = [pkgs.kdePackages.xdg-desktop-portal-kde pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk];
    };
  };
  #Sudo
  security = {
    rtkit.enable = true;
    pam.services.cosmic-greeter.enableGnomeKeyring = true;
    pam.services.cosmic-greeter.kwallet.enable = true;
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
              command = "/run/current-system/sw/bin/tlp";
              options = ["NOPASSWD"];
            }
            {
              command = "/run/current-system/sw/bin/tlp-stat";
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
              command = "/run/current-system/sw/bin/tee /sys/bus/platform/drivers/ideapad_acpi/VPC2004\\:00/conservation_mode";
              options = ["NOPASSWD"];
            }
            {
              command = "/run/current-system/sw/bin/tee /sys/firmware/acpi/platform_profile";
              options = ["NOPASSWD"];
            }
            {
              command = "/home/mate/scripts/winapps/bin/winapps";
              options = ["NOPASSWD"];
            }
          ];
          users = ["mate"];
          groups = ["wheel"];
        }
      ];
      extraConfig = with pkgs; ''
        Defaults:picloud secure_path="${lib.makeBinPath [
          systemd
        ]}:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      '';
    };
    wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      cantarell-fonts
      roboto
      openmoji-color
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
