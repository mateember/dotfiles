{
  description = "AGS v2 Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Optional: Use the official AGS flake for the latest version
    # ags.url = "github:aylur/ags"; 
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux"; # Adjust to your system if needed
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # The runner and type generator
          ags 
          
          # Libraries (Types/GIR files)
          astal.astal3
          astal.hyprland
          astal.mpris
          astal.battery
          astal.network
          astal.wireplumber
          astal.notifd
          
          # Development tools
          nodejs
          typescript
        ];

        shellHook = ''
          echo "AGS v2 Development Shell"
          # This ensures the type generator can find the GIR files in the Nix store
          export GI_TYPELIB_PATH="${pkgs.glib.out}/lib/irepository-1.0:${pkgs.gtk3.out}/lib/irepository-1.0"
        '';
      };
    };
}
