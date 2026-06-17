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
        # All container apps allocate a TTY only when stdin is a terminal, so the
        # same command works interactively AND headless (CI / agents / pipes).
        # Interactive Julia REPL; forwards the host X11 display if one exists.
        default = {
          type = "app";
          program = toString (pkgs.writeShellScript "enter-container" ''
            #!${pkgs.runtimeShell}
            TTY=""; [ -t 0 ] && TTY="-it"
            XAUTH="''${XAUTHORITY:-$HOME/.Xauthority}"
            exec docker run $TTY -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
              --volume="$XAUTH:/root/.Xauthority:ro" -e XAUTHORITY=/root/.Xauthority \
              --network=host --rm -v "$(pwd):/workdir" hrlab:latest \
              "/usr/local/julia/bin/julia --project=."
          '');
        };
        # Build the dev image (Julia 1.11 + WFDB + headless software-GL/Xvfb stack).
        build = {
          type = "app";
          program = toString (pkgs.writeShellScript "build" ''
            #!${pkgs.runtimeShell}
            exec docker build --network=host . -t hrlab:latest
          '');
        };
        # Full test suite, headless-safe: visualization tests render via Xvfb +
        # software OpenGL inside the container, so no GPU/display is required.
        #
        # Two deliberate departures from the obvious `xvfb-run … Pkg.test()`:
        #
        # 1. Start Xvfb MANUALLY instead of via `xvfb-run`. `xvfb-run -a` dead-
        #    locks in this container (podman-compat): it brings up Xvfb but never
        #    exec's the wrapped command — the container sits forever with only an
        #    Xvfb process and zero output. Launching Xvfb directly on a fixed
        #    display and pointing julia at it is reliable.
        # 2. Run test/runtests.jl DIRECTLY instead of `Pkg.test()`. Pkg.test()
        #    spins up an isolated test environment and eagerly precompiles the
        #    whole manifest — including GLMakie — into a fresh depot before
        #    running any test; that GLMakie precompile hangs indefinitely here
        #    (no GL driver, cold depot). runtests.jl against the dev project
        #    reuses the image's already-precompiled deps and starts immediately.
        #    The image instantiates every test dependency, so coverage is
        #    identical. (CI still uses julia-actions/julia-runtest = Pkg.test(),
        #    which is fine: headless CI has no display, so GLMakie is skipped.)
        #
        # GKSwstype=100 forces GR/Plots offscreen so the offline-plot tests render
        # to memory rather than poking the X server.
        #
        # 3. Mount /run/opengl-driver (read-only). The GLMakie visualization tests now
        #    create REAL Figures (the extension is live), so they need a GL driver.
        #    The image sets LD_LIBRARY_PATH=/run/opengl-driver/lib; mounting the NixOS
        #    driver tree provides llvmpipe (software GL), so GLMakie renders under Xvfb
        #    with no GPU. Without this mount the viz tests fail to create a GL context.
        test = {
          type = "app";
          program = toString (pkgs.writeShellScript "test" ''
            #!${pkgs.runtimeShell}
            TTY=""; [ -t 0 ] && TTY="-it"
            exec docker run $TTY --rm --network=host \
              -v /run/opengl-driver:/run/opengl-driver:ro \
              -v "$(pwd):/workdir" hrlab:latest \
              "Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 3; cd /workdir && DISPLAY=:99 GKSwstype=100 julia --project=. test/runtests.jl"
          '');
        };
        # Real-time LSL biofeedback visualization. Runs NATIVELY on the host (real GPU
        # + display), NOT in the container: GLMakie does not render reliably over a
        # forwarded X display, and the live viz requires the git `abcsds/LSL.jl` (modern
        # CEnum) — the registry LSL 0.3.0 drags in an ImageIO that cannot precompile on
        # Julia 1.11. A dedicated, gitignored `.viz-env` is built once on first run.
        # Usage: `nix run .#viz` (default multi-panel view) or `nix run .#viz -- geometric`
        # (also: bpm, bpm_tt, vdp_field). Requires a live LSL RR/PP stream on the network.
        viz = {
          type = "app";
          program = toString (pkgs.writeShellScript "viz" ''
            #!${pkgs.runtimeShell}
            set -e
            VIEW="''${1:-default}"
            ENVDIR="$PWD/.viz-env"
            if [ ! -f "$ENVDIR/Manifest.toml" ]; then
              echo "🔧 First run: building the real-time viz env at .viz-env (a few minutes)…"
              julia --project="$ENVDIR" -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.add(url="https://github.com/abcsds/LSL.jl"); Pkg.add(["GLMakie", "StatsBase"]); Pkg.precompile()'
            fi
            # Run the script directly in Main (where the env provides GLMakie/LSL as
            # direct deps). The Visualization.default()/etc. wrappers can't be used here:
            # they `include` the script INTO the HeartRateLab module, where `using GLMakie`
            # fails now that GLMakie is a weakdep of the package.
            case "$VIEW" in
              default)   SCRIPT=default.jl ;;
              geometric) SCRIPT=geometric.jl ;;
              bpm)       SCRIPT=heart_rate.jl ;;
              bpm_tt)    SCRIPT=heart_rate_tt.jl ;;
              vdp_field) SCRIPT=VDP_field.jl ;;
              *)         SCRIPT="$VIEW.jl" ;;
            esac
            echo "📈 Launching $SCRIPT — close the window to stop. (Needs a live LSL RR/PP stream.)"
            exec julia --project="$ENVDIR" "$PWD/src/Visualization/$SCRIPT"
          '');
        };
        # Format the tree with JuliaFormatter (BlueStyle, per .JuliaFormatter.toml).
        fmt = {
          type = "app";
          program = toString (pkgs.writeShellScript "fmt" ''
            #!${pkgs.runtimeShell}
            TTY=""; [ -t 0 ] && TTY="-it"
            exec docker run $TTY --rm --network=host -v "$(pwd):/workdir" hrlab:latest \
              "cd /workdir && julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add(\"JuliaFormatter\"); using JuliaFormatter; format(pwd())'"
          '');
        };
        act = {
          type = "app";
          program = toString (pkgs.writeShellScript "act-run" ''
            #!${pkgs.runtimeShell}
            exec ${pkgs.act}/bin/act "$@"
          '');
        };
        build-render = {
          type = "app";
          program = toString (pkgs.writeShellScript "build-render-container" ''
            #!${pkgs.runtimeShell}
            set -e

            echo "🔨 Building render container with Quarto..."
            docker build --network=host --build-arg INSTALL_QUARTO=true \
              -t hrlab:render .

            echo "✓ Render container built successfully!"
          '');
        };
        render = {
          type = "app";
          program = toString (pkgs.writeShellScript "render-notebook" ''
            #!${pkgs.runtimeShell}
            set -e

            NOTEBOOK=''${1:-flagship_demo}
            NOTEBOOK_FILE="docs/$NOTEBOOK.qmd"
            OUTPUT_FILE="docs/$NOTEBOOK.html"

            echo "📝 Rendering $NOTEBOOK notebook with code execution..."
            echo "   (make sure to run 'nix run .#build-render' first)"
            echo ""

            if [ ! -f "$NOTEBOOK_FILE" ]; then
              echo "✗ Notebook file not found: $NOTEBOOK_FILE"
              exit 1
            fi

            # Record modification time before render
            MTIME_BEFORE=$(stat -c %Y "$OUTPUT_FILE" 2>/dev/null || echo 0)

            # Run Quarto render with explicit bash entrypoint to show all output
            # Mount entire project directory to ensure fresh source code
            echo "--- Starting Quarto render ---"
            docker run --rm \
              -v "$(pwd):/workdir" \
              --entrypoint bash hrlab:render \
              -c "rm -rf /root/.julia/compiled && cd /workdir && quarto render $NOTEBOOK_FILE --to html --execute"
            RENDER_EXIT=$?
            echo "--- Quarto render completed (exit code: $RENDER_EXIT) ---"

            # Verify the output file exists and was actually modified
            if [ ! -f "$OUTPUT_FILE" ]; then
              echo ""
              echo "✗ Render failed - output file does not exist: $OUTPUT_FILE"
              exit 1
            fi

            MTIME_AFTER=$(stat -c %Y "$OUTPUT_FILE")
            if [ "$MTIME_AFTER" -le "$MTIME_BEFORE" ]; then
              echo ""
              echo "✗ Render failed - output file was not modified (render did not complete)"
              exit 1
            fi

            if [ $RENDER_EXIT -ne 0 ]; then
              echo ""
              echo "✗ Render failed with exit code $RENDER_EXIT"
              exit 1
            fi

            echo ""
            echo "✓ Notebook rendered successfully!"
            echo "📂 Output: docs/flagship_demo.html ($(stat -c %s docs/flagship_demo.html) bytes)"
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
