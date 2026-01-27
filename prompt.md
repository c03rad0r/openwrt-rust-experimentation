# Investigation into OpenWrt Build Times

## Objective

The primary goal is to understand and optimize the build process for the `tollgate-wrt` OpenWrt package, specifically when running it locally using `act`. The user is experiencing long build times and wants to ensure that the pre-compiled toolchain within the Docker image is being used effectively.

## Current Status

*   The user has initiated a local build by running `act` without any specific job arguments, which triggers the entire workflow for the default `push` event.
*   The build is currently in the "Run Package Compilation in Docker" step. We know this because the build log shows the execution of the `make package/tollgate-wrt/compile` target, which is the central command of that step. The log output also shows `make[2] -C feeds/packages/lang/rust host-compile`, indicating that the build system is recompiling parts of the Rust toolchain as a dependency of the main package build.
*   We are waiting for this compilation to complete to analyze the results.

## Investigation Steps Taken

1.  **Reduced Build Matrix:** The [`build-package.yml`](.github/workflows/build-package.yml) workflow was modified to build for a single architecture (`aarch64_cortex-a53`) to simplify and speed up the investigation.
2.  **Documentation Updates:** Several markdown files ([`BUILD_PROCESS.md`](BUILD_PROCESS.md), [`DOCKER_CACHE_TRADEOFFS.md`](DOCKER_CACHE_TRADEOFFS.md), [`DOCKER_REGISTRY_BUILD_DESIGN.md`](DOCKER_REGISTRY_BUILD_DESIGN.md), [`LOCAL_DEVELOPMENT.md`](LOCAL_DEVELOPMENT.md), [`openwrt-feeds.md`](openwrt-feeds.md)) were updated to clarify the build process, the role of Docker images, and how to use `sudo docker images` to inspect them.
3.  **Enabled Verbose Logging:** The [`build-package.yml`](.github/workflows/build-package.yml) workflow has been modified to:
    *   Add detailed logging to `/artifacts/build.log` to track the progress of the build script.
    *   Use `make -j1 V=s` for the package compilation step to get a detailed, sequential log of the build process.

## Next Steps (After Build Completion)

1.  **Analyze `build.log`:** Once the current `act` run is complete, the first step will be to examine the contents of `/tmp/tollgate-artifacts/build.log`. This log will provide a detailed trace of the build process and should reveal why the Rust toolchain is being recompiled.
2.  **Examine `.ipk` Artifact:** Check if an `.ipk` file was successfully generated in `/tmp/tollgate-artifacts`.
3.  **Further Optimization:** Based on the analysis of the `build.log`, we will determine the root cause of the recompilation and implement further optimizations to the `Dockerfile` or the `build-package.yml` workflow to ensure the pre-built toolchain is always used as intended.

## Implemented Strategy: Hybrid Build Approach

After further discussion, we have implemented a hybrid build strategy to optimize for both build speed and development flexibility. This approach is designed to prevent the recompilation of the Rust toolchain on every run.

*   **The `Dockerfile` is now specialized:**
    *   It now copies the `tollgate-wrt` source code into the image.
    *   It configures the OpenWrt SDK for the `tollgate-wrt` package during the image build.
    *   It pre-compiles the Rust toolchain with full knowledge of the `tollgate-wrt` project's dependencies.

*   **The `build-package.yml` workflow now uses a volume mount:**
    *   The `docker run` command now includes the flag `-v "${PWD}:/builder/package/tollgate-wrt"`.
    *   This mounts the local, up-to-date source code from the developer's machine over the top of the "snapshot" version that was copied into the image.

*   **The Desired Outcome:** This setup should result in the best of both worlds:
    1.  The Docker image contains a pre-built, compatible toolchain, which should prevent lengthy recompilations.
    2.  Developers can still iterate on their code locally, and the build will always use the latest version of the source code.

## Next Steps

1.  **Abort the Current Build:** The currently running `act` command is using the old Docker image and workflow. It must be stopped.
2.  **Delete Old Docker Images:** To ensure a clean rebuild with the new `Dockerfile`, the old `openwrt-rust-builder` images must be deleted. This can be done with the following commands:
    ```bash
    docker rmi openwrt-rust-builder:aarch64_cortex-a53
    docker rmi openwrt-rust-builder:mips_24kc
    ```
3.  **Run `act` Again:** After aborting the old build and deleting the old images, run the `act` command again:
    ```bash
    act -j build-and-package --container-architecture linux/amd64
    ```
4.  **Analyze the New Build:** This will trigger a new build using the updated `Dockerfile` and workflow. We will then analyze the output and the `build.log` to confirm that the toolchain is no longer being recompiled.

## Key Insights and Hypotheses

*   **The Core Problem:** The user has correctly identified that any cross-compilation that happens *inside* the `docker run` command (the "Run Package Compilation in Docker" step) is ephemeral and will be discarded when the container is destroyed. The goal is to have this compilation happen as part of the Docker image creation.

*   **The `Dockerfile`'s Intent:** The `.docker/Dockerfile` is already designed to address this. The `RUN make toolchain/install -j$(nproc)` command is intended to compile the entire cross-compilation toolchain and "bake" it into a layer of the `openwrt-rust-builder` image.

*   **Hypotheses for Recompilation:** The fact that the toolchain is being recompiled inside the container suggests one of the following:
    1.  **Cache Invalidation:** The OpenWrt build system believes the pre-built toolchain in the Docker image is "stale." This could be due to file timestamps, a configuration mismatch between the `docker build` and `docker run` environments, or differing environment variables.
    2.  **Incorrect `make` Target:** The `make toolchain/install` target might not be sufficient to pre-build all necessary components. There may be other `make` targets that need to be run in the `Dockerfile` to create a truly complete and portable toolchain.

*   **Path to Resolution:** The verbose output from the `make -j1 V=s` command, which will be captured in `build.log`, is the key to solving this. It will show the exact commands being run and the `make` dependency-checking messages (e.g., "`prereq' is newer than `target'") that are triggering the recompilation. Based on this data, we can determine whether to modify the `Dockerfile`, adjust the `docker run` command, or take other corrective actions.

---

## Current Status (as of last update)

We are in the middle of a long-running `act` build. This build is intentionally being run from a clean state to create a new, specialized Docker image that contains a pre-compiled Rust toolchain that is compatible with the `tollgate-wrt` project.

This build was triggered after a series of optimizations and fixes, including:

1.  **Specializing the `Dockerfile`:** The `Dockerfile` was modified to copy the `tollgate-wrt` source code and configure the OpenWrt SDK during the image build process.
2.  **Implementing a Hybrid Build Strategy:** The `build-package.yml` workflow was updated to mount the local source code into the container at runtime, allowing for rapid development while still using the pre-compiled toolchain.
3.  **Fixing Build Errors:** We addressed a "dubious ownership" error from Git and a "missing `rust.mk`" error from the OpenWrt build system.
4.  **Creating a `.dockerignore` file:** We created a `.dockerignore` file to prevent unnecessary rebuilds of the Docker image when irrelevant files (like the `.git` directory) are changed.

**The current build is expected to be long** because it is creating the new Docker image from scratch. Once this build is complete, subsequent builds should be significantly faster.

## Next Steps

1.  **Monitor the Current Build:** We will continue to monitor the current `act` run until it completes.
2.  **Analyze the Build Log:** Once the build is finished, we will analyze the `build.log` file to confirm that the build was successful and that the toolchain was not recompiled during the `docker run` step.
3.  **Verify the `.ipk` Artifact:** We will check for the presence of the compiled `.ipk` package in the `/tmp/tollgate-artifacts` directory.
4.  **Run `act` Again:** As a final verification step, we will run the `act` command one more time. This run should be very fast, as it will use the cached Docker image and the pre-compiled toolchain, demonstrating the full effect of our optimizations.

---

## Update: A New Testing Strategy

To accelerate our investigation, we have adopted a new strategy to quickly test our caching and `.dockerignore` setup without waiting for the full toolchain compilation.

*   **The `Dockerfile` has been temporarily modified:**
    *   All long-running `RUN` commands (including the `make package/rust/compile` step) have been commented out.
    *   A simple `RUN echo "Hello from the Dockerfile!"` command has been added.
*   **The `.dockerignore` file has been made more aggressive:**
    *   It now ignores everything except for the `Dockerfile` itself.

**The Goal of This Test:**

This will give us a very fast build. Our goal is to run `act` multiple times and observe the following:

1.  **First Run:** The `docker build` process should run and create a new image. We will verify that the build context is very small, confirming that the `.dockerignore` file is working.
2.  **Subsequent Runs:** On all subsequent runs (without any changes to the `Dockerfile`), the "Build Docker image" step should complete almost instantly, as it will be fully cached. This will prove that our caching strategy is working correctly.

Once we have confirmed that the caching is working as expected, we will then revert the changes to the `Dockerfile` and proceed with the full build.

## Next Steps

1.  **Abort the Current Build:** The currently running `act` command must be stopped.
2.  **Delete the Old Docker Image:** To ensure a clean build with the new, simplified `Dockerfile`, the `openwrt-rust-builder:aarch64_cortex-a53` image must be deleted.
3.  **Run `act` Again:** Run the `act` command to trigger the fast, diagnostic build.
4.  **Analyze the Output:** We will analyze the output to confirm that the build is fast and that the caching is working as expected.

The caching wasn't working as expected, and I noticed that commands like `make defconfig` weren't fully thought through. Hence, we will do this manually now and document our findings. 

---

## New Strategy: Manual Build First

After encountering several confusing and circular issues with the automated build process, we have decided to take a step back and adopt a more methodical, first-principles approach.

**The Goal:** To perform a complete build of the `tollgate-wrt` package manually, from start to finish, inside a clean Docker container. This will allow us to:

1.  **Understand the exact sequence of commands** required for a successful build.
2.  **Identify any hidden dependencies** or quirks in the OpenWrt build system.
3.  **Document each step** in a new `MANUAL_BUILD.md` file.
4.  **Create a reliable, repeatable process** that we can then use as a blueprint for our new, improved automation.

**The Process:**

1.  **Create `MANUAL_BUILD.md`:** A new file has been created to document the manual build process.
2.  **Start an Interactive Docker Container:** We will start an interactive shell inside a clean `openwrt/sdk` container.
3.  **Execute and Document Each Step:** We will manually execute each command required for the build, documenting the command and its output in `MANUAL_BUILD.md`.
4.  **Analyze and Optimize:** Once we have a successful manual build, we will analyze the process and decide which steps are best suited for the `Dockerfile` and which should be in the `build-package.yml` workflow.
5.  **Re-implement Automation:** With a solid understanding of the manual process, we will then build a new, robust, and efficient automated build system.

## Next Steps

1.  **Start an interactive Docker container:** We will now start an interactive shell in a clean `openwrt/sdk` container to begin the manual build process.
