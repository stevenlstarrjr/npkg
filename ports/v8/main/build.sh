#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd python3
pkg_require_cmd gn
pkg_require_cmd ninja
mkdir -p "$PKG_BUILD_DIR/gn"
cat > "$PKG_BUILD_DIR/gn/args.gn" <<'EOGN'
is_debug=false
is_component_build=true
v8_monolithic=false
target_cpu="x64"
is_clang=true
v8_use_external_startup_data=false
symbol_level=0
EOGN
( cd "$PKG_SRC_DIR" && gn gen "$PKG_BUILD_DIR/gn" --args="$(cat "$PKG_BUILD_DIR/gn/args.gn")" )
( cd "$PKG_SRC_DIR" && ninja -C "$PKG_BUILD_DIR/gn" -j"$JOBS" v8 v8_libplatform v8_libbase )
