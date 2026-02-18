#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$SCRIPT_DIR/deps"
YOGA_DIR="$DEPS_DIR/yoga"
BUILD_DIR="$SCRIPT_DIR/build_yoga"
INSTALL_DIR="$THIRDPARTY_DIR"

echo "=== Building Yoga with clang + libc++ ==="

if ! command -v clang >/dev/null 2>&1 || ! command -v clang++ >/dev/null 2>&1; then
    echo "clang/clang++ not found"
    exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
    echo "cmake not found"
    exit 1
fi

if [ ! -d "$YOGA_DIR" ]; then
    mkdir -p "$DEPS_DIR"
    cd "$DEPS_DIR"
    git clone --depth 1 https://github.com/facebook/yoga.git
fi

# Yoga's top-level CMakeLists currently adds tests unconditionally.
# Patch it to respect BUILD_TESTING so gtest is not built for this SDK build.
if grep -q "add_subdirectory(tests)" "$YOGA_DIR/CMakeLists.txt" && \
   ! grep -q "YOGA_BUILD_TESTS" "$YOGA_DIR/CMakeLists.txt"; then
    perl -0pi -e 's/add_subdirectory\(tests\)/include(CTest)\noption(YOGA_BUILD_TESTS "Build Yoga unit tests" \${BUILD_TESTING})\nif (YOGA_BUILD_TESTS)\n    add_subdirectory(tests)\nendif ()/s' "$YOGA_DIR/CMakeLists.txt"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$YOGA_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . -j"$(nproc)"
cmake --install .

echo "=== Yoga installed to $INSTALL_DIR ==="
