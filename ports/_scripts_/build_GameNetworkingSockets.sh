#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build_gns"
INSTALL_DIR="$THIRDPARTY_DIR"

echo "=== Building GameNetworkingSockets with libc++ ==="
echo "NOTE: Run build_protobuf.sh first!"

# Clone if needed
if [ ! -d "$SCRIPT_DIR/deps/GameNetworkingSockets" ]; then
    mkdir -p "$SCRIPT_DIR/deps"
    cd "$SCRIPT_DIR/deps"
    git clone --depth 1 https://github.com/ValveSoftware/GameNetworkingSockets.git
fi

# Build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SCRIPT_DIR/deps/GameNetworkingSockets" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIB=OFF \
    -DBUILD_STATIC_LIB=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF \
    -DUSE_STEAMWEBRTC=OFF \
    -DProtobuf_USE_STATIC_LIBS=ON

make -j$(nproc)

# Install
mkdir -p "$INSTALL_DIR/lib/x86_64"
cp -v src/libGameNetworkingSockets_s.a "$INSTALL_DIR/lib/x86_64/"

echo "=== Done! Enable USE_GNS in src/network/HNetworkManager.cpp ==="
