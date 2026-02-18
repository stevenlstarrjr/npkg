#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build_protobuf"
INSTALL_DIR="$THIRDPARTY_DIR"

echo "=== Building protobuf with libc++ ==="

# Clone if needed
if [ ! -d "$SCRIPT_DIR/deps/protobuf" ]; then
    mkdir -p "$SCRIPT_DIR/deps"
    cd "$SCRIPT_DIR/deps"
    git clone --depth 1 --branch v25.1 https://github.com/protocolbuffers/protobuf.git
    cd protobuf
    git submodule update --init --recursive
fi

# Build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SCRIPT_DIR/deps/protobuf" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_ABSL_PROVIDER=module \
    -DABSL_PROPAGATE_CXX_STD=ON

make -j$(nproc)
make install

echo "=== protobuf installed to $INSTALL_DIR ==="
