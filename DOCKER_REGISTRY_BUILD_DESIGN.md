# Design Doc: Docker Registry for Build Caching

This document outlines the design and implementation plan for transitioning our OpenWrt package build process from file-based caching (`actions/cache`) to a more robust image-based caching strategy using a Docker registry.

## 1. Goals

-   **Accelerate CI/CD Builds:** Drastically reduce the setup time for each build job by using a pre-built Docker image that already contains the compiled Rust toolchain and all necessary SDK dependencies.
-   **Enable Consistent Local Builds:** Provide a portable and consistent build environment that works identically on GitHub Actions and local `act` runners, eliminating the current performance gap.
-   **Improve Reliability:** Decouple the toolchain build from the package build, making the main CI pipeline more reliable and focused on its core task.

## 2. Proposed Architecture

The solution is divided into three main phases:

1.  **Create a Custom Docker Image:** A `Dockerfile` will be created to define a "pre-warmed" build environment.
2.  **Unify the Build Workflow:** The image building and package building logic will be combined into a single, unified workflow. This creates an explicit dependency chain, ensuring the builder images are always created before the package build begins, which solves any potential race conditions or dependency errors.

---

## 2.1. Separation of Concerns: "Factory" vs. "Assembly Line"

This new architecture creates a clear separation of concerns between building the development environment and building the package itself.

*   **The "Factory" (`publish-builder-image.yml`):** This workflow is responsible for the slow, complex, and infrequent task of building the entire cross-compilation toolchain. It takes the `sdk`, `openwrt_version`, and `rust_target` as parameters to produce a "pre-warmed" Docker image for a specific architecture. This is the only place where these details are needed.

*   **The "Assembly Line" (`build-package.yml`):** This is the main workflow, and its job is now much simpler. It acts as an assembly line, taking the pre-built environment (the Docker image) and simply running the package compilation inside it. Because the environment is already fully configured, this workflow no longer needs to know the specifics of the SDK version or Rust target. It only needs the `architecture` to select the correct pre-built image and to name the final package.

This separation is why it is correct to remove the `sdk`, `openwrt_version`, and `rust_target` variables from the matrix in the `build-package.yml` workflow. Their responsibility has been moved to the "factory" workflow.

---

## 3. Implementation Plan

### Phase 1: Create the Custom Dockerfile

A new `Dockerfile` will be created at the path `.docker/Dockerfile`. This file will define the custom build environment.

**`.docker/Dockerfile`:**

```dockerfile
# Use the official OpenWrt SDK image as the base
ARG SDK_TAG=mediatek-filogic-24.10.1
FROM openwrt/sdk:${SDK_TAG}

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Rust and essential build tools
RUN apt-get update && apt-get install -y curl build-essential && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Rust to the PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# The following steps will be executed within the container at build time
# to "pre-warm" the image.
WORKDIR /builder

# 1. Install OpenWrt Feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a

# 2. Patch Rust Makefile to force LLVM build from source
RUN sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' /builder/feeds/packages/lang/rust/Makefile

# 3. Pre-configure the SDK
# This creates a base .config file.
RUN make defconfig

# 4. Pre-compile the toolchain
# This is the most important step. It will trigger the lengthy compilation
# of the Rust toolchain and LLVM, saving the result into a layer of this Docker image.
RUN make toolchain/install -j$(nproc)
```

### Phase 2: Unify the Build Workflow

The image building and package building logic will be combined into a single workflow file at `.github/workflows/build-package.yml`. This creates an explicit dependency chain.

**`.github/workflows/build-package.yml` (Key Changes):**

```yaml
jobs:
  build-builder-images:
    # ... (This new job runs first)
    # It uses a matrix to build and push a pre-warmed
    # Docker image for each target architecture.

  build-package:
    # This job now depends on the successful completion
    # of the image building job.
    needs: [..., build-builder-images]
    container:
      # It dynamically selects the correct, pre-built
      # image for its architecture.
      image: ghcr.io/${{ github.repository }}/openwrt-rust-builder:${{ matrix.architecture }}
    # ... (The rest of the job is streamlined)
```

**`.github/workflows/build-package.yml` (Key Changes):**

```yaml
# ... (previous steps remain the same)

  build-package:
    needs: [determine-versioning, define-matrix]
    runs-on: ubuntu-latest
    container:
      # USE THE NEW CUSTOM IMAGE
      image: ghcr.io/${{ github.repository }}/openwrt-rust-builder:latest
      options: --user root
      volumes:
        - /tmp/tollgate-artifacts:/artifacts
    strategy:
      matrix: ${{ fromJson(needs.define-matrix.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
        with:
          path: ${{ env.PACKAGE_NAME }}/
          fetch-depth: 0

      # REMOVE the 'actions/cache' step
      # REMOVE the 'Install Rust' step
      # REMOVE the 'Update and Install Feeds' step
      # REMOVE the 'Force Disable LLVM CI Download' step

      - name: Initialize
        # ... (this step remains)

      - name: Install UPX
        # ... (this step remains)

      - name: Configure SDK for Package
        run: |
          cd /builder
          # The toolchain is already built. We just need to select our package.
          echo "CONFIG_PACKAGE_${{ env.PACKAGE_NAME }}=y" >> .config
          make defconfig

      - name: Compile Package
        # ... (this step remains the same)

# ... (rest of the file remains the same)
```

## 4. Local Development Workflow

With the unified workflow, the local development experience using `act` is seamless and mirrors the CI environment:

1.  A developer runs the `act` command to trigger the `build-package` workflow locally.
2.  The `build-builder-images` job will run first, automatically building the required pre-warmed Docker image on the developer's machine. This will be slow on the first run for each architecture. You can verify the presence of the built Docker images using `sudo docker images`.
3.  Once the local builder image is created, the `build-package` job will run, using the locally built image.
4.  Subsequent runs of `act` will be fast, as Docker will use the cached image layers from the initial build. This provides a consistent and efficient development loop.
