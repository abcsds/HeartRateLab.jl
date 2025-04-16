{
  description = "A flake that runs a Julia shell with the current project activated";

  inputs = {
    # Use the NixOS/nixpkgs repository; you might want to adjust the channel (e.g. stable/unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Declare an application called "default" that runs Julia with the current project activated
        apps.default = {
          type = "app";
          program = "${pkgs.julia}/bin/julia --project=.";
        };
      }
    );
}
