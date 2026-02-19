{
  description = "Nix flake for Julia projects";

  inputs = {
    # Pinned Nixpkgs (unstable) for full reproducibility
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Utilities for multi-platform, multi-output flakes
    flake-utils.url = "github:numtide/flake-utils";
    # helper to import Manifest.toml
    # julia2nix.url = "github:codedownio/julia2nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      # Parameter: change this to "julia-lts" or "julia-bin" for other versions
      JULIA_DIST = "julia";
      JULIA_VERSION = "1.11"; # Get the version from the Project.toml
      # JULIA_VERSION = builtins.match "julia = \"([0-9]+\\.[0-9]+\\.[0-9]+)\"" (builtins.readFile ./Project.toml);
      julia = pkgs.${JULIA_DIST};
    in {
      ### Development workflow ###
      # Define apps manually and include wrapper script definitions here
      apps = {
        default = {
          type = "app";
          program = toString (pkgs.writeShellScript "enter-container" ''
            #!${pkgs.runtimeShell}
            # docker build . -t hrlab
            # TODO: activate the GPU support in the container
            # docker run -it --network=host --rm --gpus all --name julia -v .:/workdir hrlab:latest "/usr/local/julia/bin/julia --project=."
            docker run -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --network=host --volume="$HOME/.Xauthority:/root/.Xauthority:rw" --rm --name julia -v .:/workdir hrlab:latest "/usr/local/julia/bin/julia --project=."
          '');
        };
        build = {
          type = "app";
          program = toString (pkgs.writeShellScript "build" ''
            #!${pkgs.runtimeShell}
            docker build --network=host . -t hrlab
            docker run -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --network=host --volume="$HOME/.Xauthority:/root/.Xauthority:rw" --rm -v .:/workdir hrlab:latest "/usr/local/julia/bin/julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'"
          '');
        };
        test = {
          type = "app";
          program = toString (pkgs.writeShellScript "test" ''
            #!${pkgs.runtimeShell}
            docker run -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --network=host --volume="$HOME/.Xauthority:/root/.Xauthority:rw" --rm -v .:/workdir hrlab:latest "/usr/local/julia/bin/julia --project=. -e 'using Pkg; Pkg.test()'"
          '');
        };
        act = {
          type = "app";
          program = toString (pkgs.writeShellScript "act-run" ''
            #!${pkgs.runtimeShell}
            exec ${pkgs.act}/bin/act "$@"
          '');
        };
        render = {
          type = "app";
          program = toString (pkgs.writeShellScript "render-notebook" ''
            #!${pkgs.runtimeShell}
            set -e

            # Quarto version to install
            QUARTO_VERSION="1.8.27"

            echo "🔨 Building Docker image with Quarto $QUARTO_VERSION..."
            docker build --network=host --build-arg QUARTO_VERSION=$QUARTO_VERSION . -t hrlab:latest

            echo "📝 Rendering flagship demo notebook..."
            docker run --rm -v .:/workdir hrlab:latest \
              -c 'cd /workdir && quarto render docs/flagship_demo.qmd --to html'

            echo "✓ Notebook rendered successfully!"
            echo "📂 Output: docs/flagship_demo.html"
          '');
        };
      };

      ### 2. Containerization ### TODO: Move the instructions from the Dockerfile to descriptions here
      packages.default = pkgs.dockerTools.buildImage {
        name = "ghcr.io/julia";
        tag = JULIA_VERSION;
        fromImage = pkgs.dockerTools.pullImage {
          imageName = "julia";
          imageDigest = "sha256:8e8e9611e8a2ec0b2744f3c6231d4146c19f99a081732d6217441916056b93ab";
          hash = "sha256-yNl3SnHxhHOHB4zq1/BFRxNbAcxSvciTnY2a2r6j2fE=";
          finalImageName = "julia";
          finalImageTag = JULIA_VERSION;
        };
        # # Copy the precompiled outputs into /workdir
        # copyToRoot = [ self.packages.${system}.default ];
        config = {
          Cmd = ["/bin/sh" "-c" "julia --project=."];
          Volumes = {"/workdir" = {};};
          WorkingDir = "/workdir";
        };
        # diskSize = 10 * 1024 * 1024 * 1024; # 10 GB
        # bildVMMemorySize = 2048; # 2 GB
      };
      # container = pkgs.dockerTools.buildImage {
      # container = pkgs.dockerTools.buildLayeredImage {
      #   name      = "julia";
      #   tag       = JULIA_VERSION;
      #   fromImage = "docker.io/library/julia:${JULIA_DIST}";
      #   workDir   = "/app";
      #   # Copy the precompiled outputs into /app
      #   copyToRoot = [ self.packages.${system}.default ];
      #   config = {
      #     Cmd        = [ "/bin/sh" "-c" "julia --project=/app" ];
      #     Volumes    = { "/app" = {}; };
      #     WorkingDir = "/app";
      #   };
      # };
      # my-container-image = pkgs.dockerTools.buildLayeredImage {
      #   name = "julia";
      #   tag = "1.11.3";
      #   contents = [
      #       pkgs.julia
      #   ];
      #   config = {
      #       Cmd = "julia";
      #   };
      # };

      ### 3. Dev Shell ### TODO: open the shell in the container
      # Use the modern devShells output
      devShells.default = pkgs.mkShell {
        buildInputs = [julia pkgs.openblas];
        # To include Python in your environment, uncomment below:
        # buildInputs = [ julia python3 ];
      };

      # ### Manifest.toml Import ###
      # To pin exact Julia package versions from your Manifest.toml, uncomment and
      # configure the following overlay (requires inputs.julia2nix):
      # juliaEnv = import julia2nix {
      #   inherit pkgs;
      #   projectDir = ./.;
      # };

      # # Then wrap pkgs with an overlay:
      # pkgs = import nixpkgs {
      #   inherit system;
      #   overlays = [ (self: super: { juliaEnv = juliaEnv; }) ];
      # };
    });
}
