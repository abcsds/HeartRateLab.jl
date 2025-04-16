{
  description = "Nix flake for Julia projects";

  inputs = {
    # Pinned Nixpkgs (unstable) for full reproducibility
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Utilities for multi-platform, multi-output flakes
    flake-utils.url = "github:numtide/flake-utils";
    # Optional: helper to import Manifest.toml (not enabled by default)
    # julia2nix.url = "github:codedownio/julia2nix";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      # Parameter: change this to "julia-lts" or "julia-bin" for other versions
      JULIA_DIST = "julia";
      JULIA_VERSION = "1.11";
      julia = pkgs.${JULIA_DIST};

      # Wrapper script for the default app (Julia REPL)
      juliaApp = pkgs.writeShellScriptBin "julia-repl" ''
        #!${pkgs.runtimeShell}
        exec ${julia}/bin/julia --project=. "$@"
      '';

      # Wrapper script for the test app
      juliaTestApp = pkgs.writeShellScriptBin "julia-test" ''
        #!${pkgs.runtimeShell}
        exec ${julia}/bin/julia --project=. -e 'using Pkg; Pkg.test()' "$@"
      '';

      # Wrapper script for the act app
      actApp = pkgs.writeShellScriptBin "act-run" ''
        #!${pkgs.runtimeShell}
        exec ${pkgs.act}/bin/act -W "./.github/workflows/CI.yml" -W "./.github/workflows/docs.yml" "$@"
      '';

    in {
      ### 3. Build & Precompile ###
      packages.default = pkgs.stdenv.mkDerivation {
        pname = "precompile-${JULIA_DIST}";
        version = JULIA_VERSION;
        src = ./.;
        buildInputs = [ julia ];
        buildPhase = ''
          julia --project=. -e '
            using Pkg;
            try
              Pkg.instantiate();
              Pkg.precompile();
            catch err
              println(stderr, "❌ Precompilation failed: ", err);
              throw(err);
            end
          '
        '';
        installPhase = ''
          mkdir -p $out
          # dummy file to satisfy Nix
          touch $out/.dummy
        '';
      };

      ### 4. Development "Apps" ###
      # Define apps manually instead of using flake-utils.lib.mkApp
      apps = {
        default = {
          type = "app";
          program = "${juliaApp}/bin/julia-repl";
        };
        test = {
          type = "app";
          program = "${juliaTestApp}/bin/julia-test";
        };
        act = {
          type = "app";
          program = "${actApp}/bin/act-run";
        };
      };

      ### 5. Containerization ###
      dockerImages.myImage = pkgs.dockerTools.buildImage {
        name      = "julia-project";
        tag       = JULIA_VERSION;
        fromImage = "docker.io/library/julia:${JULIA_DIST}";
        workDir   = "/app";
        # Copy the precompiled outputs into /app
        copyToRoot = [ self.packages.${system}.default ];
        config = {
          Cmd        = [ "/bin/sh" "-c" "julia --project=/app" ];
          Volumes    = { "/app" = {}; };
          WorkingDir = "/app";
        };
      };

      ### 7. Dev Shell ###
      devShell = pkgs.mkShell {
        buildInputs = [ julia ];
        # To include Python in your environment, uncomment below:
        # buildInputs = [ julia python3 ];
      };

      # ### Manifest.toml Import (Optional) ###
      #
      # To pin exact Julia package versions from your Manifest.toml, uncomment and
      # configure the following overlay (requires inputs.julia2nix):
      #
      # juliaEnv = import julia2nix {
      #   inherit pkgs;
      #   projectDir = ./.;
      # };
      #
      # Then wrap pkgs with an overlay:
      # pkgs = import nixpkgs {
      #   inherit system;
      #   overlays = [ (self: super: { juliaEnv = juliaEnv; }) ];
      # };
      #
      # This adds ~20–30 lines but ensures exact package-version reproducibility.
    });
}
