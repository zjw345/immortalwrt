# Dockerfile for OpenWrt Build Environment
# Base on Ubuntu 22.04 LTS
FROM ubuntu:22.04

# Set environment to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone to avoid interactive prompts
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install all necessary build dependencies (the "kitchen sink" approach)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext \
    gcc-multilib g++-multilib git gperf haveged help2man intltool \
    libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
    libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip-full \
    patch pkgconf python2.7 python3 python3-pyelftools python3-setuptools qemu-utils \
    rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
    vim wget xmlto xxd zlib1g-dev mkbootimg img2simg tmate file \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for building to avoid permission issues
# The user ID (1000) usually matches the default user ID on Linux/WSL.
# This helps with file ownership on mounted volumes.
RUN useradd -m -u 1000 -s /bin/bash builder

# Switch to the builder user
USER builder

# Set the working directory
WORKDIR /home/builder

# Entrypoint script will be executed when container starts
CMD ["/bin/bash"]
