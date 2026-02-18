#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
mkdir -p "$PKG_STORE_DIR/include"
if [ -d "$PKG_SRC_DIR/single_include/entt" ]; then
  cp -R "$PKG_SRC_DIR/single_include/entt" "$PKG_STORE_DIR/include/"
else
  cp -R "$PKG_SRC_DIR/src/entt" "$PKG_STORE_DIR/include/entt"
fi
