#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$SCRIPT_DIR/deps"
ANTLR_DIR="$DEPS_DIR/antlr4"
ANTLR_RUNTIME_DIR="$ANTLR_DIR/runtime/Cpp"
BUILD_DIR="$SCRIPT_DIR/build_antlr4"

INSTALL_PREFIX="${INSTALL_PREFIX:-$THIRDPARTY_DIR}"
LIB_ARCH="${LIB_ARCH:-x86_64}"
INSTALL_LIB_DIR="$INSTALL_PREFIX/lib/$LIB_ARCH"
INSTALL_INCLUDE_DIR="$INSTALL_PREFIX/include"
JOBS="${JOBS:-$(nproc)}"
ANTLR_TAG="${ANTLR_TAG:-4.13.2}"

echo "=== Building ANTLR4 C++ runtime with clang + libc++ ==="

if ! command -v git >/dev/null 2>&1; then
    echo "git not found"
    exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
    echo "cmake not found"
    exit 1
fi
if ! command -v clang >/dev/null 2>&1 || ! command -v clang++ >/dev/null 2>&1; then
    echo "clang/clang++ not found"
    exit 1
fi

mkdir -p "$DEPS_DIR"

if [ ! -d "$ANTLR_DIR/.git" ]; then
    echo "Cloning ANTLR4 source..."
    git clone --depth 1 --branch "$ANTLR_TAG" https://github.com/antlr/antlr4.git "$ANTLR_DIR"
fi

if [ ! -f "$ANTLR_RUNTIME_DIR/CMakeLists.txt" ]; then
    echo "ANTLR4 runtime CMakeLists not found: $ANTLR_RUNTIME_DIR"
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cmake -S "$ANTLR_RUNTIME_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
    -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++" \
    -DBUILD_SHARED_LIBS=ON \
    -DANTLR_BUILD_CPP_TESTS=OFF \
    -DBUILD_TESTING=OFF \
    -DDISABLE_WARNINGS=ON \
    -DWITH_LIBCXX=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR="lib/$LIB_ARCH"

cmake --build "$BUILD_DIR" -j"$JOBS"
cmake --install "$BUILD_DIR"

if [ -f "$INSTALL_PREFIX/lib/libantlr4-runtime.so" ] && [ ! -f "$INSTALL_LIB_DIR/libantlr4-runtime.so" ]; then
    mkdir -p "$INSTALL_LIB_DIR"
    cp -fv "$INSTALL_PREFIX/lib/libantlr4-runtime.so" "$INSTALL_LIB_DIR/"
fi

if [ -d "$INSTALL_PREFIX/include/antlr4-runtime" ]; then
    echo "Installed headers: $INSTALL_PREFIX/include/antlr4-runtime"
fi

echo "Installed library candidates:"
ls -1 "$INSTALL_LIB_DIR"/libantlr4-runtime.so* 2>/dev/null || true
ls -1 "$INSTALL_PREFIX"/lib/libantlr4-runtime.so* 2>/dev/null || true

echo "=== ANTLR4 runtime build/install complete ==="
