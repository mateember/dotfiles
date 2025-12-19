{
  pkgs,
  howdy-pr,
  ...
}: let
  # Access the specific package set from the PR input
  prPkgs = howdy-pr.legacyPackages.${pkgs.system};
in {
  # 1. Import the module logic from the PR files
  imports = [
    "${howdy-pr}/nixos/modules/services/security/howdy/default.nix"
    "${howdy-pr}/nixos/modules/services/misc/linux-enable-ir-emitter.nix"
    "${howdy-pr}/nixos/modules/security/pam.nix"
  ];
  disabledModules = ["security/pam.nix"];

  # 2. Configure the services using the packages from the PR
  services.linux-enable-ir-emitter = {
    enable = true;
    package = prPkgs.linux-enable-ir-emitter;
  };

  services.howdy = {
    enable = true;
    package = prPkgs.howdy;
    settings = {
      video = {
        timeout = 2;
        device_path = "/dev/video2";
        dark_threshold = 65;
      };
    };
    # pam.enable = true; # Enables Howdy for general login/auth
    # pam.unauth_timeout = 5;
  };

  # 3. Optional: Add the helper tools to your shell path
  environment.systemPackages = [
    prPkgs.howdy
    prPkgs.linux-enable-ir-emitter
  ];
  security.pam.services.sudo.howdyAuth = true;
  security.pam.services.gdm-password = {
    howdyAuth = true;
    # Force the gnome-keyring to initialize even with Howdy
    text = ''
      auth     optional    pam_gnome_keyring.so
      session  optional    pam_gnome_keyring.so auto_start
    '';
  };
}
