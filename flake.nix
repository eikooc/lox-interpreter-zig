{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:0x5a4/nixpkgs/update-zls";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.zig.url = "github:mitchellh/zig-overlay";

  outputs = { nixpkgs, flake-utils, zig, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;

          overlays = [ zig.overlays.default ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          # pkgs.zigpkgs.master
          packages = [ pkgs.bashInteractive pkgs.zigpkgs."0.13.0" pkgs.zls ];
          shellHook = ''
            echo "zig `zig version`"
          '';
        };
      });
}
