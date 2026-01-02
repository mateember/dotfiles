{
  pkgs,
  pkgs-unstable,
  ...
}: {
  # 1. Tell NixOS to use the 'unstable' package set for COSMIC specifically
  # This ensures the 'cosmic' services find their packages in the unstable branch
  nixpkgs.overlays = [
    (final: prev: {
      # This allows the system to pull the actual cosmic packages from unstable
      cosmic-packages = import pkgs-unstable {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })
  ];

  # 2. Enable COSMIC
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
}
