# Use the official OpenWrt SDK image as the base
# ARG values can be set by --build-arg flag in the docker build command
ARG SDK_TAG
ARG RUST_TARGET

FROM openwrt/sdk:${SDK_TAG}

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Rust and essential build tools
RUN apt-get update && apt-get install -y curl build-essential && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Rust to the PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Install the cross-compilation target for the specific architecture
RUN rustup target add ${RUST_TARGET}

# The following steps will be executed within the container at build time
# to "pre-warm" the image.
WORKDIR /builder

# 1. Install OpenWrt Feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a

# 2. Configure the SDK and Toolchain
# This creates a base .config file, explicitly sets our required toolchain option,
# and includes a failsafe sed command to guarantee the LLVM download is disabled.
RUN make defconfig && \
    echo "CONFIG_RUST_DOWNLOAD_CI_LLVM=n" >> .config && \
    make defconfig && \
    sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' /builder/feeds/packages/lang/rust/Makefile

# 4. Pre-compile the toolchain
# This is the most important step. It will trigger the lengthy compilation
# of the Rust toolchain and LLVM, saving the result into a layer of this Docker image.
RUN make toolchain/install -j$(nproc)
