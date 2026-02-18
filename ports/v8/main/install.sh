#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
mkdir -p "$PKG_STORE_DIR/lib" "$PKG_STORE_DIR/include"
for f in libv8.so libv8_libplatform.so libv8_libbase.so; do
  [ -f "$PKG_BUILD_DIR/gn/$f" ] && cp "$PKG_BUILD_DIR/gn/$f" "$PKG_STORE_DIR/lib/"
done
for f in libv8.a libv8_libplatform.a libv8_libbase.a; do
  [ -f "$PKG_BUILD_DIR/gn/obj/$f" ] && cp "$PKG_BUILD_DIR/gn/obj/$f" "$PKG_STORE_DIR/lib/"
done
cp -R "$PKG_SRC_DIR/include/." "$PKG_STORE_DIR/include/"
