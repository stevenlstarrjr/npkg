#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd meson
meson install -C "$PKG_BUILD_DIR/meson" --no-rebuild
