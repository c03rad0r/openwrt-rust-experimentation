# Caching Strategies for OpenWrt Builds

This document outlines the tradeoffs between two different caching strategies for accelerating the OpenWrt package build process in a CI/CD environment: **File-Based Caching** (using `actions/cache`) and **Image-Based Caching** (using a Docker registry).

---

## 1. File-Based Caching (`actions/cache`)

This is the strategy currently implemented in our `.github/workflows/build-package.yml` workflow.

-   **How it Works:** This method saves specific directories from within the build container (`/builder/staging_dir`, `/builder/build_dir`, `/builder/dl`) to GitHub's dedicated cache storage at the end of a successful job. On subsequent runs, it downloads and extracts this cache into a fresh `openwrt/sdk` container before the build steps begin.

-   **Pros:**
    -   **Simple to Implement:** It can be added to an existing workflow with just a few lines of YAML.
    -   **Effective for Toolchains:** It is highly effective at solving the immediate problem of long compilation times for dependencies like the Rust toolchain and LLVM.
    -   **Integrated with GitHub Actions:** It's a native feature of GitHub Actions, requiring no external services or setup.

-   **Cons:**
    -   **Platform Specific:** It is a GitHub Actions feature and **does not work with local runners like `act`**. This leads to a significant discrepancy in build times between local and remote environments.
    -   **Doesn't Cache the Full Environment:** The base `openwrt/sdk` container is still pulled from Docker Hub on every run. The cache is then downloaded and layered on top, which adds some overhead.
    -   **Cache Invalidation:** The cache is tied to a key. If any part of the key changes (e.g., SDK version), the entire cache is invalidated and must be rebuilt from scratch.

---

## 2. Image-Based Caching (Docker Registry)

This strategy involves creating a custom, "pre-warmed" Docker image that already contains the fully built toolchain and dependencies.

-   **How it Works:** You would create a `Dockerfile` that uses the `openwrt/sdk` image as a base. This `Dockerfile` would then contain all the steps needed to install the Rust toolchain and compile LLVM. The resulting image is then pushed to a Docker registry (like GitHub Container Registry or Docker Hub). The CI workflow would then use this custom image directly instead of the generic `openwrt/sdk` image.

-   **Pros:**
    -   **Universal and Portable:** The pre-built image can be pulled and used by any container runtime, including GitHub Actions, local `act` runners, and developers' local machines. This creates a consistent and fast build environment for everyone.
    -   **Faster Job Startup:** The CI job starts with a container that is already 99% ready. It completely skips the toolchain installation and compilation steps, leading to significantly faster build times.
    -   **More Reliable:** It decouples the toolchain build process from the package build process. If the toolchain build fails, it's a separate issue that doesn't block every package build.

-   **Cons:**
    -   **More Complex Setup:** It requires creating and maintaining a separate `Dockerfile` for the build environment.
    -   **Requires a Registry:** You need to set up and manage a Docker registry to store the custom images.
    -   **Maintenance Overhead:** The custom Docker image needs to be rebuilt and republished whenever the base SDK changes or when you need to update the Rust toolchain or other core dependencies. This typically involves setting up a separate workflow that triggers on a schedule or when the `Dockerfile` changes.

---

## Summary and Recommendation

| Feature                  | File-Based Caching (`actions/cache`) | Image-Based Caching (Docker Registry) |
| ------------------------ | ------------------------------------ | ------------------------------------- |
| **Setup Complexity**     | Low                                  | Medium                                |
| **Performance**          | Good (after first run)               | Excellent                             |
| **Local Runner (`act`)** | Not Supported                        | Fully Supported                       |
| **Consistency**          | Low (local vs. remote)               | High (consistent everywhere)          |
| **Maintenance**          | Low                                  | Medium                                |

-   **Current Approach (`actions/cache`):** This is an excellent starting point and effectively solves the immediate performance bottleneck on GitHub Actions.
-   **Future Improvement (Docker Registry):** Migrating to an image-based caching approach is the recommended next step if you require fast, consistent builds across both GitHub Actions and local development environments. It is a more robust and scalable long-term solution.
