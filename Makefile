include $(TOPDIR)/rules.mk

PKG_NAME:=openwrt-rust-experimentation
PKG_VERSION:=0.0.1 #$(PACKAGE_VERSION)


PKG_MAINTAINER:=Your Name <your@email.com>
PKG_LICENSE:=CC0-1.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=TollGate Basic Module
	SUBMENU:=VPN
endef

define Package/openwrt-rust-experimentation/description
	TollGate Basic Module for OpenWrt
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
# Nothing to do here for us.
# By default openwrt-rust-experimentation/src/Makefile will be used.
endef

define Build/Compile
	$(call Rust/Compile)
endef

define Package/openwrt-rust-experimentation/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(RUST_BIN_DIR)/$(PKG_NAME) $(1)/usr/bin/openwrt-rust-experimentation
endef


$(eval $(call BuildPackage,$(PKG_NAME)))

# Print IPK path after successful compilation
PKG_FINISH:=$(shell echo "Successfully built: $(IPK_FILE)" >&2)
