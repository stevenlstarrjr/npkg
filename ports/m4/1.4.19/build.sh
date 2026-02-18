#!/bin/sh
set -eu
# Placeholder build script for m4 recipe.
mkdir -p "${PKG_BUILD_DIR:?}/out"
printf 'm4 build output\n' > "${PKG_BUILD_DIR}/out/m4.txt"
