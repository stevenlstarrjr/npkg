#!/bin/sh
set -eu
# Install from build output into store path.
mkdir -p "${PKG_STORE_DIR:?}/share/example"
cp "${PKG_BUILD_DIR:?}/out/example.txt" "${PKG_STORE_DIR}/share/example/example.txt"
