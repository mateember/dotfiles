{
  description = "My NixOS flake";

  inputs = {
    #nixpkgs-unstable.follows = "nixos-cosmic/nixpkgs"; # NOTE: change "nixpkgs" to "nixpkgs-stable" to use stable NixOS release

    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nur.url = "github:nix-community/NUR";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      #url = "github:nix-community/home-manager/release-24.05";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    chaotic,
    hyprland,
    zen-browser,
    nixos-cosmic,
    vscode-server,
    ...
  }: let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    lib-unstable = nixpkgs-unstable.lib;
    pkgs = import nixpkgs {
      config.allowUnfree = true;
      localSystem = {inherit system;};
    };

    #pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    pkgs-unstable = import nixpkgs-unstable {
      config.allowUnfree = true;
      localSystem = {inherit system;};
    };
  in {
    nixosConfigurations = {
      matenix = lib-unstable.nixosSystem {
        inherit system;
        modules = [
          ./system/matenix/configuration.nix
          chaotic.nixosModules.default

          #chaotic.homeManagerModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.mate = import ./system/matenix/home;
            home-manager.backupFileExtension = "nixbk";
            home-manager.extraSpecialArgs = {
              inherit pkgs;
              inherit pkgs-unstable;
              inherit hyprland;
            };
          }
        ];

        specialArgs = {
          inherit pkgs-unstable;
          inherit hyprland;
        };
      };

      matevono = lib-unstable.nixosSystem {
        inherit system;
        modules = [
          ./system/matevono/configuration.nix
          chaotic.nixosModules.default
          nixos-cosmic.nixosModules.default

          #chaotic.homeManagerModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.mate = import ./system/matevono/home;
            home-manager.backupFileExtension = "nixbk";
            home-manager.extraSpecialArgs = {
              inherit pkgs;
              inherit pkgs-unstable;
              inherit zen-browser;
            };
          }
        ];

        specialArgs = {
          inherit pkgs-unstable;
          inherit zen-browser;
        };
      };
      homelab = lib.nixosSystem {
        inherit system;
        modules = [
          vscode-server.nixosModules.default
          ./system/homelab/configuration.nix
        ];


      specialArgs = {
          inherit pkgs-unstable;
          
        };
      


      };
    };
  };
}
