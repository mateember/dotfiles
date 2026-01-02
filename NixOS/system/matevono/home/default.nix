{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hyprland
    ./programs
    ./shell
    #./waybar
    #./dunst
    #./rofi
    #./wlogout
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "mate";
    homeDirectory = "/home/mate";

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "25.11";
  };

  systemd.user = {
    services = {
      bing-wallpaper = {
        Unit = {
          Description = "Download Bing Daily Wallpaper";
          After = ["network-online.target"];
          Wants = ["network-online.target"];
        };

        Service = {
          Type = "oneshot";
          # Ensure the path matches where you saved the script
          ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.scripts/bingpaper.sh";
        };

        Install = {
          WantedBy = ["default.target"];
        };
      };
    };
  };

  # Systemd Timer definition
  systemd.user.timers.bing-wallpaper = {
    Unit = {
      Description = "Run Bing Wallpaper script daily";
    };

    Timer = {
      OnCalendar = "daily"; # Runs every day at midnight
      Persistent = true; # Runs immediately if the computer was off during scheduled time
      Unit = "bing-wallpaper.service";
    };

    Install = {
      WantedBy = ["timers.target"];
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
