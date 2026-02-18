#!/bin/sh
set -eu
# Placeholder build script for example recipe.
mkdir -p "${PKG_BUILD_DIR:?}/out"
printf 'example build output\n' > "${PKG_BUILD_DIR}/out/example.txt"
