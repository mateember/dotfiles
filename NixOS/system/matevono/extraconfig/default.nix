{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./udev.nix
  ];
}
