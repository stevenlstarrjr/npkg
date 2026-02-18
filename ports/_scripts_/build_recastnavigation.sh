#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build_recast"
INSTALL_DIR="$THIRDPARTY_DIR"

echo "=== Building Recast Navigation with libc++ ==="

# Clone if needed
if [ ! -d "$SCRIPT_DIR/deps/recastnavigation" ]; then
    mkdir -p "$SCRIPT_DIR/deps"
    cd "$SCRIPT_DIR/deps"
    git clone --depth 1 https://github.com/recastnavigation/recastnavigation.git
fi

# Build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SCRIPT_DIR/deps/recastnavigation" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DRECASTNAVIGATION_DEMO=OFF \
    -DRECASTNAVIGATION_TESTS=OFF \
    -DRECASTNAVIGATION_EXAMPLES=OFF

make -j$(nproc)

# Install manually
echo "=== Installing libraries ==="
mkdir -p "$INSTALL_DIR/lib/x86_64"
mkdir -p "$INSTALL_DIR/include/recast"

cp -v Recast/libRecast.a "$INSTALL_DIR/lib/x86_64/"
cp -v Detour/libDetour.a "$INSTALL_DIR/lib/x86_64/"
cp -v DetourCrowd/libDetourCrowd.a "$INSTALL_DIR/lib/x86_64/"
cp -v DetourTileCache/libDetourTileCache.a "$INSTALL_DIR/lib/x86_64/"
cp -v DebugUtils/libDebugUtils.a "$INSTALL_DIR/lib/x86_64/"

cp -v "$SCRIPT_DIR/deps/recastnavigation/Recast/Include/"*.h "$INSTALL_DIR/include/recast/"
cp -v "$SCRIPT_DIR/deps/recastnavigation/Detour/Include/"*.h "$INSTALL_DIR/include/recast/"
cp -v "$SCRIPT_DIR/deps/recastnavigation/DetourCrowd/Include/"*.h "$INSTALL_DIR/include/recast/"
cp -v "$SCRIPT_DIR/deps/recastnavigation/DetourTileCache/Include/"*.h "$INSTALL_DIR/include/recast/"
cp -v "$SCRIPT_DIR/deps/recastnavigation/DebugUtils/Include/"*.h "$INSTALL_DIR/include/recast/"

echo "=== Recast Navigation installed to $INSTALL_DIR ==="
