# Build Process Documentation

This document outlines the build process for the `tollgate-wrt` OpenWrt package, which is built from a Rust application. The entire process is automated using a GitHub Actions workflow defined in `.github/workflows/build-package.yml`.

## Overview

The primary goal of the build process is to compile the Rust source code into an `.ipk` package that can be installed on various OpenWrt devices. This involves cross-compiling for multiple CPU architectures.

## CI/CD Pipeline (GitHub Actions)

The workflow is triggered on every push to the repository. It uses a matrix strategy to build the package for a predefined set of architectures.

### Key Steps in the Build Job (`build-package`):

1.  **Containerized Build Environment**: The build runs inside a Docker container. This ensures a consistent and reproducible build environment with all the necessary tools and dependencies.
    *   The Docker image `openwrt-rust-builder` is built from the `.docker` directory.
    *   You can inspect locally built images using `sudo docker images`.
    *   Images are tagged with the architecture (e.g., `openwrt-rust-builder:aarch64_cortex-a53`).
    *   These images are persistent on your local Docker daemon once built.

2.  **Source Checkout**: The workflow checks out the source code of the repository.

3.  **Caching**:
    *   The workflow uses the `actions/cache@v4` action to cache the OpenWrt build directories (`/builder/staging_dir`, `/builder/build_dir`, and `/builder/dl`).
    *   **IMPORTANT**: This caching mechanism is a feature of the GitHub Actions platform and **will not work when using a local `act` runner**.
    *   The cache is crucial for performance. The first time the build runs for a specific architecture, it must compile the entire Rust toolchain and the LLVM compiler from source, which is a very time-consuming process.
    *   Subsequent builds for the same architecture will find a cache hit, download the cached directories, and skip the lengthy toolchain compilation, resulting in a much faster build time.

4.  **Rust Toolchain Installation**: The workflow installs the `nightly` Rust toolchain using `rustup` and adds the necessary cross-compilation target for the current architecture in the matrix.

5.  **OpenWrt Feeds**: It updates and installs the OpenWrt package feeds. This is necessary to make the Rust build system (`rust.mk`) available to the build environment.

6.  **Toolchain Build Fix**: A critical step is included to work around a build issue with the Rust toolchain. The build system attempts to download a pre-compiled version of LLVM from a URL that is no longer available, resulting in a 404 error. To fix this, the workflow runs a `sed` command to modify the Rust package's `Makefile` directly, forcing it to build LLVM from source instead of downloading it.

7.  **SDK Configuration**: The workflow configures the OpenWrt SDK by creating a `.config` file with the necessary package selections and then running `make defconfig` to generate the final build configuration.

8.  **Package Compilation**: The main compilation step is triggered with `make package/tollgate-wrt/compile`. This invokes the OpenWrt build system, which in turn uses `rust.mk` to cross-compile the Rust application and package it into an `.ipk` file.

9.  **Artifact Upload**: The resulting `.ipk` package is uploaded as a build artifact, making it available for download from the GitHub Actions run summary page.

## Skipping Workflow Steps (Local Development with `act`)

When running the workflow locally using `act`, you might want to skip certain steps to speed up development or testing. Here's how:

*   **Skipping Docker Image Build**: If the `openwrt-rust-builder` Docker image for a specific architecture already exists in your local Docker daemon (you can check with `sudo docker images`), you can skip the `build_image` step. `act` will automatically use the existing image if it finds one with the correct tag.

*   **Skipping `define-matrix` and `determine-versioning`**: If you only want to run the `build-and-package` job for a specific architecture and version, you can directly invoke `act` for that job and provide the necessary environment variables or inputs. However, it's generally recommended to let these jobs run to ensure correct matrix and versioning are applied.

*   **Skipping `publish-metadata` and `trigger-build-os`**: These jobs are responsible for publishing the package metadata and triggering downstream workflows. For local development, you will almost always want to skip these. You can do this by specifying only the `build-and-package` job when running `act`:
    ```bash
    act -j build-and-package --container-architecture linux/amd64
    ```
    Remember to replace `linux/amd64` with the appropriate architecture if you're targeting a different one.

*   **Checking for `.ipk` files**: After a successful local `act` run of the `build-and-package` job, the generated `.ipk` files will be located in `/tmp/tollgate-artifacts` on your host machine. You can verify their presence using `ls -l /tmp/tollgate-artifacts`.
