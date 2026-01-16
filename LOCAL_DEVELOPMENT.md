# Local Development with `act`

This document provides instructions on how to use [`act`](https://github.com/nektos/act), a local runner for GitHub Actions, to build and test this project on your local machine.

Our new, unified build architecture is fully compatible with `act`, allowing you to replicate the CI environment for rapid development and testing.

## 1. Prerequisites

Before you begin, you must have the following software installed on your system:

1.  **[Docker](https://docs.docker.com/get-docker/):** `act` uses Docker to execute jobs in containers.
2.  **[`act`](https://github.com/nektos/act#installation):** The local GitHub Actions runner.

## 2. Running the Build

The process for running a local build is straightforward.

### Step 1: Navigate to the Project Directory

Open your terminal and navigate to the root of this repository.

```bash
cd /path/to/openwrt-rust-experimentation
```

### Step 2: Run `act`

Execute the `act` command without any arguments. This will detect and run the default `push` event defined in `.github/workflows/build-package.yml`.

```bash
act
```

### What to Expect

1.  **First Run (Slow):** The first time you run `act`, it will execute the `build-builder-images` job. This will build the "pre-warmed" Docker images for each architecture defined in the matrix, which involves the lengthy process of compiling the Rust toolchain and LLVM. This is a one-time cost for each architecture.

2.  **Subsequent Runs (Fast):** On all subsequent runs, Docker will use its cached layers, and the `build-builder-images` job will complete very quickly.

3.  **Package Build:** Once the builder images are available locally, the `build-package` job will run, using the appropriate image to compile the `.ipk` package. This step will be fast on every run.

## 3. Handling Secrets

The final job, `publish-metadata`, requires secrets (`NSEC_HEX`) to publish release information. When running `act` locally, you will likely see an error during this job because the secret is not available.

This is expected and can be safely ignored if your goal is simply to build and test the package. The `.ipk` file will have already been successfully created.

If you need to test the publishing steps, you can provide secrets to `act` using a `.secrets` file in the project root.

**`.secrets` file example:**

```
NSEC_HEX=your_secret_here
REPO_ACCESS_TOKEN=your_token_here
```

Then run `act` with the `--secret-file` flag:

```bash
act --secret-file .secrets
```

## 4. Build Artifacts

The compiled `.ipk` packages will be placed in an `artifacts` directory at the root of the project. `act` automatically creates this directory to store the outputs from the workflow.

## 5. Troubleshooting

### "Permission Denied" Connecting to Docker

You may encounter an error message similar to this when running `act`:

```
Error: permission denied while trying to connect to the Docker daemon socket...
```

This happens when your user account does not have the necessary permissions to access the Docker socket (`/var/run/docker.sock`).

#### Permanent Fix (Recommended)

The best way to resolve this is to add your user to the `docker` group. This will grant you the required permissions permanently.

1.  **Add your user to the `docker` group:**

    ```bash
    sudo usermod -aG docker $USER
    ```

2.  **Apply the new group membership:** For the changes to take effect, you must either **log out and log back in**, or **reboot your machine**. Simply opening a new terminal is often not sufficient.

#### Temporary Workaround

If you cannot log out or reboot, you can use the `sg` command to run `act` with the `docker` group's permissions for a single session. This is a temporary fix.

```bash
sg docker -c "act"
```

This command executes `act` as if you were a member of the `docker` group, but only for that one command.

## 6. How the "act-aware" Workflow Works

The `build-package.yml` workflow has been specifically modified to work seamlessly with `act`.

-   The `docker/login-action` step is skipped when `act` is detected, so it won't try to log in to a remote registry.
-   The `docker/build-push-action` is configured to:
    -   `push: false` when run with `act`, preventing it from trying to upload the image.
    -   `load: true` when run with `act`, which tells it to load the newly built builder image directly into your local Docker daemon, making it immediately available for the next job in the workflow.
