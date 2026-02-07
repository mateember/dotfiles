{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: let
  # Access the specific package set from the PR input
in {
  # 1. Import the module logic from the PR files
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/security/howdy/default.nix"
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/linux-enable-ir-emitter.nix"
    "${inputs.nixpkgs-unstable}/nixos/modules/security/pam.nix"
  ];
  disabledModules = ["security/pam.nix"];

  # 2. Configure the services using the packages from the PR
  services.linux-enable-ir-emitter = {
    enable = true;
    package = pkgs-unstable.linux-enable-ir-emitter;
  };

  services.howdy = {
    enable = true;
    package = pkgs-unstable.howdy;
    settings = {
      video = {
        timeout = 2;
        device_path = "/dev/video2";
        dark_threshold = 70;
        certainty = 4.0;
      };
    };
    # pam.enable = true; # Enables Howdy for general login/auth
    # pam.unauth_timeout = 5;
  };

  # 3. Optional: Add the helper tools to your shell path
  environment.systemPackages = [
    pkgs-unstable.howdy
    pkgs-unstable.linux-enable-ir-emitter
  ];
  security.pam.howdy = {
    enable = true;
    control = "sufficient";
  };
}
