#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd make
if [ ! -x "$PKG_SRC_DIR/configure" ] && [ -x "$PKG_SRC_DIR/autogen.sh" ]; then
  (cd "$PKG_SRC_DIR" && sh ./autogen.sh)
fi
cd "$PKG_BUILD_DIR"
"$PKG_SRC_DIR/configure" \
  CC="${CC:-cc}" CXX="${CXX:-c++}" \
  CFLAGS="${CFLAGS:--O2 -fPIC}" CXXFLAGS="${CXXFLAGS:--O2 -fPIC}" \
  --prefix="$PKG_STORE_DIR" --libdir="$PKG_STORE_DIR/lib" \
  --enable-static --disable-shared
make -j"$JOBS"
