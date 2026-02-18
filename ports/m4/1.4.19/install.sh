#!/bin/sh
set -eu
# Install from build output into store path.
mkdir -p "${PKG_STORE_DIR:?}/bin"
cp "${PKG_BUILD_DIR:?}/out/m4.txt" "${PKG_STORE_DIR}/bin/m4"
chmod +x "${PKG_STORE_DIR}/bin/m4"
