# HeartRateLab unified container - use INSTALL_QUARTO build arg for different modes
# Usage:
#   docker build . -t hrlab:latest                         # Development/testing
#   docker build . --build-arg INSTALL_QUARTO=true -t hrlab:render  # Quarto rendering

FROM julia:1.11-bookworm

# Build argument for optional Quarto installation
ARG INSTALL_QUARTO=false

# Create a working directory within the container
WORKDIR /workdir

# Install base build tools, WFDB deps, and a HEADLESS software-OpenGL + Xvfb stack
# so GLMakie can render in CI/agents/containers without a GPU or real display.
RUN apt-get update && \
    apt-get -y install \
    gcc \
    make \
    xvfb \
    xauth \
    libgl1-mesa-dri \
    libglu1-mesa \
    libegl1 \
    libopengl0 \
    libxrandr2 \
    libxinerama1 \
    libxcursor1 \
    libxi6 \
    libxext6 \
    libxrender1 \
    libxfixes3 \
    libx11-6 \
    libxkbcommon0 \
    libfontconfig1

# Install Quarto dependencies if INSTALL_QUARTO=true
RUN if [ "$INSTALL_QUARTO" = "true" ]; then \
    apt-get -y install \
    curl \
    gdebi-core \
    python3 \
    python3-pip \
    python3-venv; \
    fi

# Install WFDB tools (always)
ADD https://www.physionet.org/physiotools/archives/wfdb-10.7/wfdb-10.7.0.tar.gz wfdb-10.7.0.tar.gz
RUN tar -xzf wfdb-10.7.0.tar.gz && rm wfdb-10.7.0.tar.gz
RUN cd wfdb-10.7.0 && ./configure && make install && cd ..

# Copy project files (Project.toml and Manifest.toml for reproducible builds)
COPY Project.toml Manifest.toml /workdir/

# Set environment variables
# DISPLAY defaults to :0 but headless rendering goes through Xvfb (see below).
# LIBGL_ALWAYS_SOFTWARE forces Mesa llvmpipe so GLMakie renders with no GPU.
# LD_LIBRARY_PATH keeps the NixOS GL driver path for optional GPU passthrough;
# harmless when empty (software GL via apt Mesa is used by default).
ENV DISPLAY=${DISPLAY:-:0}
ENV LD_LIBRARY_PATH="/run/opengl-driver/lib"
ENV LIBGL_ALWAYS_SOFTWARE=1

# Resolve and instantiate Julia packages
# GLMakie is a weak dependency, so core loads without a GPU; if Manifest.toml is out
# of sync with Project.toml (e.g. GLMakie moved to [weakdeps]) resolve first.
RUN julia -e 'using Pkg; Pkg.activate("/workdir"); try Pkg.instantiate() catch; Pkg.resolve(); Pkg.instantiate() end'

# Precompile under a virtual X display so GLMakie + the visualization extension
# precompile cleanly headless. Core packages don't need it; the `|| true` keeps the
# build resilient if an optional weakdep precompile workload misbehaves.
RUN xvfb-run -a julia --project=/workdir -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "function_registry" || true

# Install and configure Quarto if INSTALL_QUARTO=true
RUN if [ "$INSTALL_QUARTO" = "true" ]; then \
    pip3 install jupyter --break-system-packages && \
    curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v1.8.27/quarto-1.8.27-linux-amd64.deb && \
    gdebi --non-interactive quarto-1.8.27-linux-amd64.deb && \
    rm quarto-1.8.27-linux-amd64.deb && \
    julia -e 'using Pkg; Pkg.add("IJulia")' && \
    julia -e 'using Pkg; Pkg.add("Plots")' && \
    julia -e 'using Pkg; Pkg.add("StatsPlots")' && \
    julia -e 'using Pkg; Pkg.add("CairoMakie")' && \
    julia -e 'using IJulia; IJulia.installkernel("Julia", env=Dict("JULIA_PROJECT"=>"/workdir"))' && \
    sed -i 's|"/usr/local/julia/bin/julia",|"/usr/local/julia/bin/julia", "--project=/workdir",|' /root/.local/share/jupyter/kernels/julia-1.11/kernel.json; \
    fi

# Copy and use entrypoint script for flexible command/interactive handling
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
