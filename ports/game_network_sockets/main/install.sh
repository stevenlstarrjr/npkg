#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
mkdir -p "$PKG_STORE_DIR/lib" "$PKG_STORE_DIR/include"
[ -f "$PKG_BUILD_DIR/cmake/src/libGameNetworkingSockets_s.a" ] && cp "$PKG_BUILD_DIR/cmake/src/libGameNetworkingSockets_s.a" "$PKG_STORE_DIR/lib/"
[ -d "$PKG_SRC_DIR/include" ] && cp -R "$PKG_SRC_DIR/include/." "$PKG_STORE_DIR/include/"
