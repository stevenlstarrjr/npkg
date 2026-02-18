#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
mkdir -p "$PKG_STORE_DIR/lib" "$PKG_STORE_DIR/include/recast"
for f in Recast/libRecast.a Detour/libDetour.a DetourCrowd/libDetourCrowd.a DetourTileCache/libDetourTileCache.a DebugUtils/libDebugUtils.a; do
  [ -f "$PKG_BUILD_DIR/cmake/$f" ] && cp "$PKG_BUILD_DIR/cmake/$f" "$PKG_STORE_DIR/lib/"
done
for d in Recast Detour DetourCrowd DetourTileCache DebugUtils; do
  [ -d "$PKG_SRC_DIR/$d/Include" ] && cp "$PKG_SRC_DIR/$d/Include"/*.h "$PKG_STORE_DIR/include/recast/" 2>/dev/null || true
done
