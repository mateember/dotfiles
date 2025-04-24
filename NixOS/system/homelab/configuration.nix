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
    ./configs/nginx_block.nix
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      allowed-users = ["mate"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

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
      allowPing = true;
      trustedInterfaces = [];
      allowedTCPPorts = [443 61208];
      allowedUDPPorts = [];
      allowedTCPPortRanges = [
        # {from = 26910; to = 26912; }
      ];
      allowedUDPPortRanges = [
        {
          from = 26910;
          to = 26912;
        }
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
  users = {
    groups = {
      mate.gid = 1000;
    };
    users = {
      mate = {
        isNormalUser = true;
        description = "Máté Tamás Kiss";
        extraGroups = ["networkmanager" "wheel" "docker"];
        shell = pkgs.fish;
        linger = true;
        packages = with pkgs; [];
      };
    };
  };

  security.tpm2.enable = false;
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  programs = {
    fish.enable = true;
    nix-ld.enable = true;
    steam = {
      enable = false;
      dedicatedServer.openFirewall = true;
    };
  };
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    neovim
    fish
    starship
    lazygit
    zoxide
    git
    fastfetch
    speedtest-cli
    zellij
    tmux
    vbetool
    killall
    bat
    gh
    trash-cli
    wirelesstools
    glances
    unzip
    btop
    ddclient
    iw
    gcc
    steamcmd
    distrobox

    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];

  systemd.units."dev-tpmrm0.device".enable = false;
  systemd = {
    user.services = {
      "kshare" = {
        enable = true;
        after = ["network.target"];
        wantedBy = ["default.target"];
        description = "Http File server";
        serviceConfig = {
          Type = "simple";
          ExecStart = ''/home/mate/goserver/ghfs --config /home/mate/goserver/ghfs.conf'';
        };
      };

      "kshare_home" = {
        enable = true;
        after = ["network.target"];
        wantedBy = ["default.target"];
        description = "Http File server";
        serviceConfig = {
          Type = "simple";
          ExecStart = ''/home/mate/goserver/ghfs -l 8181 -r /home/mate --global-upload --global-mkdir --global-delete --global-archive'';
        };
      };

      "glances-manual" = {
        description = "Glances manual";
        enable = true;
        after = ["multi-user.target" "network.target"];
        serviceConfig = {
          Type = "simple";
          ExecStart = ''/run/current-system/sw/bin/glances --port 61208 --webserver --disable-plugin gpu'';
        };
        wantedBy = ["default.target"];
      };
    };
    services = {
      "set_fb_blank_1" = {
        description = "Set framebuffer blank state to 1";
        enable = true;
        after = ["multi-user.target"];
        script = "echo 1 > /sys/class/graphics/fb0/blank";
        wantedBy = ["multi-user.target"];
      };
    };
  };
  services = {
    tailscale.enable = true;
    tailscale.openFirewall = true;
    vscode-server.enable = true;
    fail2ban.enable = true;

    jellyfin = {
      enable = false;
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

      commonHttpConfig = ''
        log_format bot_logs '$remote_addr - $http_user_agent - $request';
        limit_conn_zone $binary_remote_addr zone=addr:10m;
      '';
      virtualHosts."hl.kmate.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/jellyfin" = {
          proxyPass = "http://127.0.0.1:8096";
          extraConfig = ''limit_conn addr 20; '';
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
          extraConfig = ''limit_conn addr 10; '';
        };
        locations."/films" = {
          proxyPass = "http://127.0.0.1:7777";
          extraConfig = ''
            limit_conn addr 10;
            client_max_body_size 12G;
          '';
        };

        extraConfig = ''

          if ($bad_bot) { return 444; }
          if ($bad_urls) { return 444; }

          access_log /var/log/nginx/crawlers.log bot_logs if=$bad_bot;
          access_log /var/log/nginx/bots.log bot_logs if=$bad_urls;




        '';
      };
    };

    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "Home Samba Share";
          "netbios name" = "HOMELAB";
          "security" = "user";
          #"use sendfile" = "yes";
          #"max protocol" = "smb2";
          # note: localhost is the ipv6 localhost ::1
          "hosts allow" = "192.168.0. 192.168.1. 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "bad user";
        };
        "public" = {
          "path" = "/mnt/khdd";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "guest only" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "writeable" = "yes";
        };
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
    ddclient.enable = true;
    ddclient.configFile = "/home/mate/randomfiles/ddclient/ddclient.conf";

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
