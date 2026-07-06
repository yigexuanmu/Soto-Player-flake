{
  description = "Soto Player-Community — Nix package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.default = pkgs.callPackage ./default.nix { };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/soto-player";
        };

        overlays.default = final: prev: {
          soto-player-community = final.callPackage ./default.nix { };
        };
      }
    )
    // {
      overlays.default = final: prev: {
        soto-player-community = final.callPackage ./default.nix { };
      };
    };
}
