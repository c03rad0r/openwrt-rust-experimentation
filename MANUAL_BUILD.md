# Manual OpenWrt Build Process

This document outlines the step-by-step process for manually building the `tollgate-wrt` OpenWrt package. This process is designed to be run inside a clean OpenWrt SDK container.

## 1. Start an Interactive Docker Container

The first step is to start an interactive shell inside the `openwrt/sdk` container. This will give us a clean build environment.

```bash
docker run -it --rm openwrt/sdk
```

## 2. Install Dependencies

Next, we need to install the essential build tools and dependencies.

```bash
apt-get update && apt-get install -y curl build-essential
```

## 3. Install Rust

Now, we will install the `nightly` Rust toolchain.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
. "$HOME/.cargo/env"
```

## 4. Update and Install Feeds

Next, we will update the OpenWrt package feeds and install the `rust` package.

```bash
./scripts/feeds update -a
./scripts/feeds install rust
```

## 5. Configure the SDK

Now, we will configure the OpenWrt SDK for our specific package.

```bash
echo "CONFIG_TARGET_bcm27xx=y" > .config
echo "CONFIG_TARGET_bcm27xx_bcm2710=y" >> .config
echo "CONFIG_TARGET_BOARD=\"bcm27xx\"" >> .config
echo "CONFIG_PACKAGE_tollgate-wrt=y" >> .config
make defconfig
```

## 6. Compile the Toolchain

This is the most time-consuming step. We will now compile the cross-compilation toolchain.

```bash
make toolchain/install -j$(nproc)
```

## 7. Compile the Package

Finally, we will compile the `tollgate-wrt` package.

```bash
make package/tollgate-wrt/compile -j$(nproc)
```
