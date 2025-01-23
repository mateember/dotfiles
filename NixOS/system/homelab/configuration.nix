# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bootloader.

  boot = {
    consoleLogLevel = 3;
    kernelModules = ["tcp_bbr" "v4l2loopback"];
    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
      "net.core.wmem_max" = 1073741824;
      "net.core.rmem_max" = 1073741824;
      "net.ipv4.tcp_rmem" = "4096 87380 1073741824";
      "net.ipv4.tcp_wmem" = "4096 87380 1073741824";
    };
    kernelParams = [];
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot"; # ← use the same mount point here.
      };
      grub = {
        efiSupport = true;
        useOSProber = true;
        #efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
        device = "nodev";
      };
    };
  };

  networking.hostName = "homelab"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [443];
      allowedUDPPortRanges = [
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Budapest";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "hu_HU.UTF-8";
    LC_IDENTIFICATION = "hu_HU.UTF-8";
    LC_MEASUREMENT = "hu_HU.UTF-8";
    LC_MONETARY = "hu_HU.UTF-8";
    LC_NAME = "hu_HU.UTF-8";
    LC_NUMERIC = "hu_HU.UTF-8";
    LC_PAPER = "hu_HU.UTF-8";
    LC_TELEPHONE = "hu_HU.UTF-8";
    LC_TIME = "hu_HU.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "hu";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "hu";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mate = {
    isNormalUser = true;
    description = "Máté Tamás Kiss";
    extraGroups = ["networkmanager" "wheel" "docker"];
    shell = pkgs.fish;
    packages = with pkgs; [];
  };

  security.tpm2.enable = false;
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  programs = {
    fish.enable = true;
    nix-ld.enable = true;
  };
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    neovim
    fish
    starship
    zoxide
    git
    fastfetch
    speedtest-cli
    zellij
    tmux
    vbetool
    bat
    gh
    trash-cli
    wirelesstools
    glances
    btop
    ddclient
    iw
    distrobox

    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];

  systemd.units."dev-tpmrm0.device".enable = false;
  systemd.services = {
    "set_fb_blank_1" = {
      description = "Set framebuffer blank state to 1";
      enable = true;
      after = ["multi-user.target"];
      script = "echo 1 > /sys/class/graphics/fb0/blank";
      wantedBy = ["multi-user.target"];
    };
  };
  services = {
    tailscale.enable = true;
    vscode-server.enable = true;

    glances = {
      enable = true;
      extraArgs = ["-w" "--disable-webui"];
      openFirewall = true;
      package = pkgs-unstable.glances;
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
      user = "mate";
    };

    nextcloud = {
      enable = false;
      package = pkgs.nextcloud30;
      hostName = "hl.kmate.org";
      config.adminpassFile = "/etc/nextcloud-admin-pass";
      database.createLocally = true;
      https = true;
    };

    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."hl.kmate.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/jellyfin" = {
          proxyPass = "http://127.0.0.1:8096";
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
        };
        locations."/films" = {
          proxyPass = "http://127.0.0.1:8181";
        };
      };
    };

    ddclient.enable = true;
    ddclient.configFile = "/home/mate/.local/ddclient/ddclient.conf";

    logind.lidSwitch = "ignore";
    logind.powerKey = "poweroff";
  };

  virtualisation.docker = {
    enable = true;
  };

  security = {
    acme = {
      acceptTerms = true;
      defaults.email = "attilathetroll@gmail.com";
    };
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  system.stateVersion = "24.11"; # Did you read the comment?
}
