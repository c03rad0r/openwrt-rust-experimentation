# Debugging the Docker Image Build Process

When building Docker images, especially complex ones like our `openwrt-rust-builder`, it's important to know how to inspect the build process and debug any issues that may arise. This document outlines several methods for viewing the logs and state of the Docker image build.

## 1. Real-Time Output from `act`

This is the primary and most direct way to see what's happening during the image build.

*   **How it works:** When you run the `act` command, the "Build Docker image" step in the workflow executes a `docker build` command. The output of this command is streamed directly to your terminal in real-time.
*   **What to look for:** The output is structured as a series of steps, each corresponding to a `RUN` command in your `Dockerfile`. You will see the command being executed and its output directly in your terminal. This is the best way to see the full compiler output from the `make toolchain/install` step.

**Example Output:**

```
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 32B
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [internal] load metadata for docker.io/library/ubuntu:latest
 => [auth] library/ubuntu:pull token for registry-1.docker.io
 => [internal] load build context
 => => transferring context: 2.84kB
 => [1/5] FROM docker.io/library/ubuntu@sha256:...
 => CACHED [2/5] RUN apt-get update && apt-get install -y curl
 => [3/5] RUN make toolchain/install -j1 V=s
    ... (lots of compiler output here) ...
 => [4/5] WORKDIR /app
 => [5/5] COPY . .
 => exporting to image
 => => exporting layers
 => => writing image sha256:...
 => => naming to docker.io/library/my-image
```

## 2. Using `docker history` (After the Build)

Once an image has been successfully built, you can use the `docker history` command to get a high-level overview of how it was created.

*   **How it works:** The `docker history` command shows the list of commands that were used to create each layer of the image, along with the size of each layer.
*   **What it's good for:** This is useful for quickly verifying which commands were run and for seeing how much space each step adds to the image. It does **not** show the log output of the commands, only the commands themselves.

**Example Command:**

```bash
docker history openwrt-rust-builder:aarch64_cortex-a53
```

## 3. Docker's Build Cache (For Advanced Debugging)

If a `docker build` fails, you can use Docker's build cache to launch a container that is in the exact state of the build just before the failure. This is a very powerful technique for interactive debugging.

*   **How it works:**
    1.  **Find the ID of the failed build step:** In the `docker build` output, each step has an ID (e.g., `[3/5]`).
    2.  **Run a container from the cached layer:** You can use the `docker run` command with a special `--mount=type=cache...` flag to mount the build cache for a specific step. This will give you a shell inside a container where you can examine files, check environment variables, and manually re-run the failed command to see what's going wrong.
*   **What it's good for:** This is the best way to debug complex build failures that are not immediately obvious from the log output.

## Summary for Our Current Situation

The most important tool for our current investigation is the **real-time output from the `act` command**. This will provide the verbose logs from the `RUN make package/rust/compile -j1 V=s` step in our `Dockerfile`, which is where the toolchain is being compiled. By analyzing this output, we can understand why the toolchain is being recompiled and how to fix it.
