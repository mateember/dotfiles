{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    howdy-pr.url = "github:NixOS/nixpkgs?ref=pull/216245/head";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nur.url = "github:nix-community/NUR";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omarchy-nix = {
      url = "github:henrysipp/omarchy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
    };
    ags.url = "github:Aylur/ags";
    astal.url = "github:aylur/astal";
		  astal.inputs.nixpkgs.follows = "nixpkgs";
  ags.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    chaotic,
    hyprland,
    zen-browser,
    vscode-server,
    winapps,
    omarchy-nix,
    hyprdynamicmonitors,
    stylix,
    howdy-pr,
    ags,
    astal,
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
          #chaotic.nixosModules.default

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

      matevono = lib.nixosSystem {
        inherit system;
        modules = [
          ./system/matevono/configuration.nix
          chaotic.nixosModules.default
          stylix.nixosModules.stylix

          # omarchy-nix.nixosModules.default
          # chaotic.homeManagerModules.default
          home-manager.nixosModules.home-manager
          {
            #  omarchy = {
            #    full_name = "Máté Tamás Kiss";
            #    email_address = "mate@kmate.org";
            #    theme = "tokyo-night";
            #  };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users."mate" = {
              imports = [
                # omarchy-nix.homeManagerModules.default
                ./system/matevono/home
                stylix.homeModules.stylix
                ags.homeManagerModules.default
              ]; # And this one
            };
            home-manager.backupFileExtension = "nixbk";
            home-manager.extraSpecialArgs = {
              #inherit pkgs;
              inherit pkgs-unstable;
              inherit zen-browser;
              inherit hyprland;
              inherit hyprdynamicmonitors;
              inherit astal;
            };
          }
        ];

        specialArgs = {
          inherit pkgs-unstable;
          inherit zen-browser;
          inherit hyprland;
          inherit winapps;
          inherit howdy-pr;
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
