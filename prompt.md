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
