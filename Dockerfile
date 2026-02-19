# Use the official julia 1.11 image as a base
FROM julia:1.11-bookworm

# Quarto version (update this as new versions are released)
ARG QUARTO_VERSION=1.8.27

# Create a working directory within the container
WORKDIR /workdir

# https://archive.physionet.org/physiotools/wfdb-linux-quick-start.shtml
RUN apt-get update && \
    apt-get -y install \
    gcc \
    make \
    curl \
    gdebi-core
    # libcurl4-openssl-dev \
    # libexpat1-dev

# Install Quarto for notebook rendering
RUN curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    gdebi --non-interactive quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    rm quarto-${QUARTO_VERSION}-linux-amd64.deb

ADD https://www.physionet.org/physiotools/archives/wfdb-10.7/wfdb-10.7.0.tar.gz wfdb-10.7.0.tar.gz
RUN tar -xzf wfdb-10.7.0.tar.gz && rm wfdb-10.7.0.tar.gz
RUN cd wfdb-10.7.0 && ./configure && make install && cd ..

COPY Project.toml /workdir/
COPY Manifest.toml /workdir/

# Environment Variable for X11 forwarding
# ENV DISPLAY=:0
ENV DISPLAY=${DISPLAY:-:0}
ENV LD_LIBRARY_PATH="/run/opengl-driver/lib"

# Instantiate the julia environment
RUN julia -e 'using Pkg; Pkg.activate("/workdir"); Pkg.instantiate()'

# Use bash as entrypoint to allow flexible command execution
# For interactive shell: docker run -it hrlab:latest
# For commands: docker run hrlab:latest bash -c 'command'
ENTRYPOINT [ "bash" ]