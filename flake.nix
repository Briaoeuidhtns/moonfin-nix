{
  description = "Moonfin desktop media client for Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # These cores have redistributable, non-commercial licenses.
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "libretro-fbneo"
                "libretro-genesis-plus-gx"
                "libretro-snes9x"
                "moonfin-cores"
              ];
          };
        in
        rec {
          moonfin-cores = pkgs.callPackage ./pkgs/moonfin-cores.nix { };
          moonfin-desktop = pkgs.callPackage ./pkgs/moonfin-desktop.nix { cores = moonfin-cores; };
          default = moonfin-desktop;
        }
      );

      apps = forSystems (system: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.moonfin-desktop;
          meta.description = "Moonfin desktop media client";
        };
      });

      checks = forSystems (system: {
        native-cores = import ./checks/cores.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          moonfin = self.packages.${system}.moonfin-desktop;
        };
      });

      formatter = forSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
