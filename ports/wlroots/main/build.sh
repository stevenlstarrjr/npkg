#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd meson
pkg_require_cmd ninja
meson setup "$PKG_BUILD_DIR/meson" "$PKG_SRC_DIR" \
  --buildtype release \
  --prefix "$PKG_STORE_DIR" 
meson compile -C "$PKG_BUILD_DIR/meson" -j "$JOBS"
