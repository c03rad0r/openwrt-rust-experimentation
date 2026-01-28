# Manual OpenWrt Build Process

This document outlines the step-by-step process for manually building the `tollgate-wrt` OpenWrt package. This process is designed to be run inside a clean OpenWrt SDK container.

## 1. Start an Interactive Docker Container

The first step is to start an interactive shell inside the `openwrt/sdk` container. This will give us a clean build environment.

```bash
sudo docker run -it --rm --user root openwrt/sdk
```

## 2. Install Dependencies

Next, we need to install `git` and other essential build tools.

```bash
apt-get update && apt-get install -y git curl build-essential
```

## 3. Clone OpenWrt Source Code

Now, we will clone the OpenWrt source code into a new `openwrt` directory and `cd` into it.

```bash
git clone https://github.com/openwrt/openwrt.git
cd openwrt
root@bdd9b7f29cd8:/builder/openwrt# ls
BSDmakefile  config  Config.in  COPYING  feeds.conf.default  include  LICENSES  Makefile  package  README.md  rules.mk  scripts  target  toolchain  tools
```

result: this worked

## 3. Install Rust

Now, we will install the `nightly` Rust toolchain.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
. "$HOME/.cargo/env"
```

## 4. Update Feeds

Next, we will update the OpenWrt package feeds.

```bash
./scripts/feeds update -a
```

result: update -a returned 503 unreachable for most feeds.

Changing:
```
root@bdd9b7f29cd8:/builder/openwrt# cat feeds.conf.default 
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
src-git telephony https://git.openwrt.org/feed/telephony.git
src-git video https://github.com/openwrt/video.git
#src-git targets https://github.com/openwrt/targets.git
#src-git oldpackages http://git.openwrt.org/packages.git
#src-link custom /usr/src/openwrt/custom-feed
```

to
```
root@bdd9b7f29cd8:/builder/openwrt# cat feeds.conf.default 
src-git packages https://github.com/openwrt/packages.git
src-git luci https://github.com/openwrt/luci.git
src-git routing https://github.com/openwrt/routing.git
src-git telephony https://github.com/openwrt/telephony.git
src-git video https://github.com/openwrt/video.git
src-git tollgate https://github.com/OpenTollGate/tollgate-feed.git
#src-git targets https://github.com/openwrt/targets.git
#src-git oldpackages http://git.openwrt.org/packages.git
```

`./scripts/feeds update -a` seems to work now!
`./scripts/feeds install -a` also seems to work now!
`./scripts/feeds install -p tollgate` because install -a only seems to install the default packages
echo "CONFIG_PACKAGE_openwrt-rust-experimentation=y" >> .config && make defconfig

I think install only works if update worked.


## 5. Configure the SDK and Select Rust

Now, we will launch the menuconfig interface to select the `rust` package. This is a crucial step, as it makes the `rust` package available to the build system.

Now, we will configure the OpenWrt SDK for our specific package.

```bash
make defconfig
```

This also works now. I think `make defconfig` only works if install worked.

Backed up in: /home/c03rad0r/openwrt-rust-experimentation/.config.installa.updatea.defconfig

```bash
make menuconfig
```
Inside the `menuconfig` interface, navigate to `Languages --->` and select `rust` by pressing `y`. Then, save and exit.

```
root@bdd9b7f29cd8:/builder/openwrt# cat .config | grep "rust"
CONFIG_PACKAGE_trusted-firmware-a-mt7981-nor-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-spim-nand-ubi-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7987-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-ddr4=y
# CONFIG_PACKAGE_kmod-keys-trusted is not set
CONFIG_PACKAGE_rust=y
# CONFIG_PACKAGE_luci-app-rustdesk-server is not set
```

Its ok to do `make defconfig` after making changes to `.config`, because `make defconfig` doesn't overwrite the changes we already made to the config file.

TODO: once our build pipeline is working as intended, let make a 




## 6. Install Rust

Now that the `rust` package has been selected in the configuration, we can install it.

```bash
./scripts/feeds install -a
./scripts/feeds install rust
```


## 6. Compile the Toolchain

This is the most time-consuming step. We will now compile the cross-compilation toolchain.

```bash
FORCE_UNSAFE_CONFIGURE=1 make toolchain/install -j$(nproc) V=sc
```

## 7. Compile the Package

Finally, we will compile the `tollgate-wrt` package.

```bash
FORCE_UNSAFE_CONFIGURE=1
make package/tollgate-wrt/compile -j$(nproc) V=sc
```
