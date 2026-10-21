{
  description = "Moonfin desktop media client for Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          moonfin-desktop = pkgs.callPackage ./pkgs/moonfin-desktop.nix { };
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

      formatter = forSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
