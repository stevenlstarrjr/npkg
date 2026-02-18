#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd cmake
cmake -S "$PKG_SRC_DIR" -B "$PKG_BUILD_DIR/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PKG_STORE_DIR" \
  -DBUILD_SHARED_LIB=OFF \
  -DBUILD_STATIC_LIB=ON \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTS=OFF
cmake --build "$PKG_BUILD_DIR/cmake" -- -j"$JOBS"
