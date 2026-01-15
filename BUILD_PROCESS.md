# Build Process Documentation

This document outlines the build process for the `tollgate-wrt` OpenWrt package, which is built from a Rust application. The entire process is automated using a GitHub Actions workflow defined in `.github/workflows/build-package.yml`.

## Overview

The primary goal of the build process is to compile the Rust source code into an `.ipk` package that can be installed on various OpenWrt devices. This involves cross-compiling for multiple CPU architectures.

## CI/CD Pipeline (GitHub Actions)

The workflow is triggered on every push to the repository. It uses a matrix strategy to build the package for a predefined set of architectures.

### Key Steps in the Build Job (`build-package`):

1.  **Containerized Build Environment**: The build runs inside a Docker container provided by OpenWrt (`openwrt/sdk`). This ensures a consistent and reproducible build environment with all the necessary tools and dependencies.

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
