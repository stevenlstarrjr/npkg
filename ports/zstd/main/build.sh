#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd cmake
pkg_require_cmd c++
pkg_require_cmd cc
cmake -S "$PKG_SRC_DIR" -B "$PKG_BUILD_DIR/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PKG_STORE_DIR" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON 
cmake --build "$PKG_BUILD_DIR/cmake" -- -j"$JOBS"
