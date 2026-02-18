#!/bin/sh
set -eu
. "$(dirname "$0")/../../_scripts_/freebsd_common.sh"
pkg_init
pkg_require_cmd make
cd "$PKG_BUILD_DIR"
make install
