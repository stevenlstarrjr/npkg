#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd cmake
cmake -S "$PKG_SRC_DIR" -B "$PKG_BUILD_DIR/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PKG_STORE_DIR" \
  -DRECASTNAVIGATION_DEMO=OFF \
  -DRECASTNAVIGATION_TESTS=OFF \
  -DRECASTNAVIGATION_EXAMPLES=OFF
cmake --build "$PKG_BUILD_DIR/cmake" -- -j"$JOBS"
