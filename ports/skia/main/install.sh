#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
mkdir -p "$PKG_STORE_DIR/lib" "$PKG_STORE_DIR/include/skia"
for f in libskia.a libsksg.a libsvg.a libskottie.a libskparagraph.a libskshaper.a; do
  [ -f "$PKG_BUILD_DIR/skia/$f" ] && cp "$PKG_BUILD_DIR/skia/$f" "$PKG_STORE_DIR/lib/"
done
cp -R "$PKG_SRC_DIR/include/." "$PKG_STORE_DIR/include/skia/"
