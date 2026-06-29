# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=newsboat
PKG_VERSION:=2.44
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://newsboat.org/releases/$(PKG_VERSION)
PKG_HASH:=8cb376b14c44809750a41b74c239a47092edb8e496f657c38af9b852dd8e4ea4

PKG_MAINTAINER:=Stan Grishin <stangri@melmac.ca>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=rust/host

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

define Package/newsboat
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=RSS/Atom feed reader for text terminals
  URL:=https://newsboat.org/
  DEPENDS:=$(RUST_ARCH_DEPENDS) \
	+libstfl \
	+libsqlite3 \
	+libcurl \
	+libxml2 \
	+libjson-c \
	+libncursesw \
	+libstdcpp \
	+ca-bundle
endef

define Package/newsboat/description
  Newsboat is an RSS/Atom feed reader for the text console. It is a fork of
  the Newsbeuter feed reader. It supports OPML import/export, podcast
  downloading (via the bundled podboat tool), tagging, and custom commands.
endef

# Newsboat probes its build dependencies with pkg-config via config.sh, which
# writes config.mk (included by its Makefile). Point it at the target staging
# tree so it picks up the cross-compiled libraries (stfl, sqlite3, curl, xml2,
# json-c, ncursesw) instead of the host's.
define Build/Configure
	( cd $(PKG_BUILD_DIR); \
		PKG_CONFIG="pkg-config" \
		PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig" \
		PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig" \
		PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
		./config.sh )
endef

# Newsboat has its own Makefile that compiles the C++ sources and invokes cargo
# to build the Rust static library (libnewsboat.a), then links them together.
# CARGO_PKG_CONFIG_VARS (from rust-package.mk) carries the cross cargo
# environment: CARGO_BUILD_TARGET, the target linker, profile flags, etc.
# The C++ flags are passed via the environment (not as make overrides) so
# newsboat's own Makefile can still append its required include paths; -Wno-error
# keeps a newer toolchain's warnings non-fatal.
define Build/Compile
	+$(CARGO_PKG_CONFIG_VARS) \
	CARGO_HOME="$(CARGO_HOME)" \
	CXX="$(TARGET_CXX)" \
	CXX_FOR_BUILD="$(HOSTCXX)" \
	CXXFLAGS="$(TARGET_CXXFLAGS) $(TARGET_CPPFLAGS) -Wno-error" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	prefix=/usr \
	$(MAKE) -C $(PKG_BUILD_DIR) newsboat podboat
endef

define Package/newsboat/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/newsboat $(1)/usr/bin/newsboat
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/podboat $(1)/usr/bin/podboat
endef

$(eval $(call BuildPackage,newsboat))
