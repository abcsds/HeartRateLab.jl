# HeartRateLab unified container - use INSTALL_QUARTO build arg for different modes
# Usage:
#   docker build . -t hrlab:latest                         # Development/testing
#   docker build . --build-arg INSTALL_QUARTO=true -t hrlab:render  # Quarto rendering

FROM julia:1.11-bookworm

# Build argument for optional Quarto installation
ARG INSTALL_QUARTO=false

# Create a working directory within the container
WORKDIR /workdir

# Install base build tools and WFDB dependencies
RUN apt-get update && \
    apt-get -y install \
    gcc \
    make

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

# Copy project files
COPY Project.toml Manifest.toml /workdir/

# Set environment variables
ENV DISPLAY=${DISPLAY:-:0}
ENV LD_LIBRARY_PATH="/run/opengl-driver/lib"

# Instantiate Julia packages
RUN julia -e 'using Pkg; Pkg.activate("/workdir"); Pkg.instantiate()'

# Precompile packages to speed up first use
RUN julia --project=/workdir -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "function_registry" || true

# Install and configure Quarto if INSTALL_QUARTO=true
RUN if [ "$INSTALL_QUARTO" = "true" ]; then \
    pip3 install jupyter --break-system-packages && \
    curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v1.8.27/quarto-1.8.27-linux-amd64.deb && \
    gdebi --non-interactive quarto-1.8.27-linux-amd64.deb && \
    rm quarto-1.8.27-linux-amd64.deb && \
    julia --project=/workdir -e 'using Pkg; Pkg.add("IJulia")' && \
    julia --project=/workdir -e 'using IJulia; IJulia.installkernel("Julia", env=Dict("JULIA_PROJECT"=>"/workdir"))' && \
    sed -i 's|"/usr/local/julia/bin/julia",|"/usr/local/julia/bin/julia", "--project=/workdir",|' /root/.local/share/jupyter/kernels/julia-1.11/kernel.json; \
    fi

# Copy and use entrypoint script for flexible command/interactive handling
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
