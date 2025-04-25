# Use the official julia 1.11 image as a base
FROM julia:1.11.3-bullseye

# Create a working directory within the container
WORKDIR /workdir

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -y install gcc make

# Copy the Manifest to the working directory
COPY Manifest.toml /workdir/

# Instantiate the julia environment
# RUN julia -e 'using Pkg; Pkg.activate("/workdir"); Pkg.instantiate()'

# TODO: requires a compiler
ADD http://physionet.org/physiotools/wfdb.tar.gz wfdb.tar.gz
RUN tar -xzf wfdb.tar.gz && rm wfdb.tar.gz
RUN cd wfdb-10.7.0 && ./configure && make install && cd ..

# Set the working directory to /workdir
WORKDIR /workdir
