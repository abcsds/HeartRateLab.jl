# Use the official julia 1.11 image as a base
FROM julia:1.11-bookworm

# Create a working directory within the container
WORKDIR /workdir

# https://archive.physionet.org/physiotools/wfdb-linux-quick-start.shtml
RUN apt-get update && \
    apt-get -y install \
    gcc \
    make 
    # libcurl4-openssl-dev \
    # libexpat1-dev

ADD https://www.physionet.org/physiotools/archives/wfdb-10.7/wfdb-10.7.0.tar.gz wfdb-10.7.0.tar.gz
RUN tar -xzf wfdb-10.7.0.tar.gz && rm wfdb-10.7.0.tar.gz
RUN cd wfdb-10.7.0 && ./configure && make install && cd ..

COPY Project.toml /workdir/

# Environment Variable for X11 forwarding
# ENV DISPLAY=:0
ENV DISPLAY=${DISPLAY:-:0}
ENV LD_LIBRARY_PATH="/run/opengl-driver/lib"

# Instantiate the julia environment
RUN julia -e 'using Pkg; Pkg.activate("/workdir"); Pkg.instantiate()'

ENTRYPOINT [ "bash", "-c", "-l", "/usr/local/julia/bin/julia --project=. -i" ]