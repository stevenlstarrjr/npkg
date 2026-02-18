#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd python3
pkg_require_cmd gn
pkg_require_cmd ninja
mkdir -p "$PKG_BUILD_DIR/skia"
cat > "$PKG_BUILD_DIR/skia/args.gn" <<'EOGN'
is_official_build=true
is_component_build=false
skia_use_vulkan=true
skia_use_gl=false
skia_enable_svg=true
skia_enable_skottie=true
skia_enable_skparagraph=true
skia_enable_skshaper=true
EOGN
( cd "$PKG_SRC_DIR" && gn gen "$PKG_BUILD_DIR/skia" --args="$(cat "$PKG_BUILD_DIR/skia/args.gn")" )
( cd "$PKG_SRC_DIR" && ninja -C "$PKG_BUILD_DIR/skia" -j"$JOBS" )
