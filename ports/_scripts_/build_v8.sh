#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$SCRIPT_DIR/deps"
DEPOT_TOOLS_DIR="$DEPS_DIR/depot_tools"
V8_DIR="$DEPS_DIR/v8"
BUILD_DIR="$V8_DIR/out/hultrix_release"
GN_ARGS_FILE="$SCRIPT_DIR/build_v8.args.gn"

INSTALL_PREFIX="${INSTALL_PREFIX:-$THIRDPARTY_DIR}"
LIB_ARCH="${LIB_ARCH:-x86_64}"
INSTALL_LIB_DIR="$INSTALL_PREFIX/lib/$LIB_ARCH"
INSTALL_INCLUDE_DIR="$INSTALL_PREFIX/include"

JOBS="${JOBS:-$(nproc)}"

echo "=== Building V8 ==="

if ! command -v git >/dev/null 2>&1; then
    echo "git not found"
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found"
    exit 1
fi

if ! command -v clang >/dev/null 2>&1 || ! command -v clang++ >/dev/null 2>&1; then
    echo "clang/clang++ not found"
    exit 1
fi

mkdir -p "$DEPS_DIR"

if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    echo "Cloning depot_tools..."
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git \
        "$DEPOT_TOOLS_DIR"
fi

export PATH="$DEPOT_TOOLS_DIR:$PATH"

if [ -x "$DEPOT_TOOLS_DIR/update_depot_tools" ]; then
    "$DEPOT_TOOLS_DIR/update_depot_tools" >/dev/null || true
fi

if ! command -v fetch >/dev/null 2>&1 || ! command -v gclient >/dev/null 2>&1; then
    echo "fetch/gclient not found in PATH after depot_tools setup"
    exit 1
fi

has_valid_v8_head() {
    [ -d "$V8_DIR/.git" ] && git -C "$V8_DIR" rev-parse --verify HEAD >/dev/null 2>&1
}

if [ ! -d "$V8_DIR/.git" ]; then
    PARTIAL_V8_DIR="$(find "$DEPS_DIR" -maxdepth 1 -type d -name '_gclient_v8_*' | head -n 1 || true)"
    if [ -n "$PARTIAL_V8_DIR" ] && [ -d "$PARTIAL_V8_DIR/.git" ]; then
        echo "Recovering partial V8 checkout from $(basename "$PARTIAL_V8_DIR") ..."
        mv "$PARTIAL_V8_DIR" "$V8_DIR"
        (
            cd "$V8_DIR"
            git checkout -f HEAD >/dev/null 2>&1 || true
        )
    fi
fi

if [ -d "$V8_DIR/.git" ] && ! has_valid_v8_head; then
    echo "Detected broken V8 checkout (missing HEAD), removing and refetching..."
    rm -rf "$V8_DIR"
fi

if [ ! -d "$V8_DIR/.git" ]; then
    # fetch refuses to run when a .gclient exists, and a stale unmanaged
    # .gclient from an interrupted run will block recovery.
    rm -f "$DEPS_DIR/.gclient"
    echo "Fetching V8 source..."
    (
        cd "$DEPS_DIR"
        fetch v8
    )
fi

if ! has_valid_v8_head; then
    echo "V8 checkout not found after fetch/sync"
    exit 1
fi

if [ -f "$DEPS_DIR/.gclient" ] && grep -q '"managed"[[:space:]]*:[[:space:]]*False' "$DEPS_DIR/.gclient"; then
    echo "Unmanaged gclient solution detected; skipping explicit gclient sync."
else
    echo "Syncing V8 dependencies..."
    (
        cd "$DEPS_DIR"
        gclient sync -D
    )
fi

cat > "$GN_ARGS_FILE" <<'EOF'
is_debug = false
is_component_build = true
v8_monolithic = false
target_cpu = "x64"
is_clang = true
use_custom_libcxx = true
v8_use_external_startup_data = false
symbol_level = 0
treat_warnings_as_errors = false
use_siso = false
use_remoteexec = false
use_reclient = false
enable_rust = false
use_clang_modules = false
v8_enable_temporal_support = false
EOF

echo "Generating GN build files..."
(
    cd "$V8_DIR"
    mkdir -p "$BUILD_DIR"
    export CC=clang
    export CXX=clang++
    # If this output directory was previously used by Siso, switch it to Ninja.
    if [ -f "$BUILD_DIR/.siso_deps" ] || [ -f "$BUILD_DIR/.siso_env" ] || [ -f "$BUILD_DIR/.siso_last_targets" ]; then
        echo "Cleaning stale Siso state from $BUILD_DIR ..."
        gn clean "$BUILD_DIR"
    fi
    gn gen "$BUILD_DIR" --args="$(cat "$GN_ARGS_FILE")"
)

echo "Compiling V8 targets..."
(
    cd "$V8_DIR"
    ninja -C "$BUILD_DIR" -j"$JOBS" v8 v8_libplatform v8_libbase
)

echo "Installing headers and libraries to $INSTALL_PREFIX ..."
mkdir -p "$INSTALL_LIB_DIR" "$INSTALL_INCLUDE_DIR"

# Shared libs are preferred so CMake find_library(NAMES v8 ...) picks libv8.so.
if [ -f "$BUILD_DIR/libv8.so" ]; then
    cp -fv "$BUILD_DIR/libv8.so" "$INSTALL_LIB_DIR/"
fi
if [ -f "$BUILD_DIR/libv8_libplatform.so" ]; then
    cp -fv "$BUILD_DIR/libv8_libplatform.so" "$INSTALL_LIB_DIR/"
fi
if [ -f "$BUILD_DIR/libv8_libbase.so" ]; then
    cp -fv "$BUILD_DIR/libv8_libbase.so" "$INSTALL_LIB_DIR/"
fi

# Fallback to static libs if shared libs are unavailable.
if [ -f "$BUILD_DIR/obj/libv8.a" ]; then
    cp -fv "$BUILD_DIR/obj/libv8.a" "$INSTALL_LIB_DIR/"
fi
if [ -f "$BUILD_DIR/obj/libv8_libplatform.a" ]; then
    cp -fv "$BUILD_DIR/obj/libv8_libplatform.a" "$INSTALL_LIB_DIR/"
fi
if [ -f "$BUILD_DIR/obj/libv8_libbase.a" ]; then
    cp -fv "$BUILD_DIR/obj/libv8_libbase.a" "$INSTALL_LIB_DIR/"
fi

# Public headers expected by modules/scripting.
cp -afv "$V8_DIR/include/"*.h "$INSTALL_INCLUDE_DIR/" 2>/dev/null || true
if [ -d "$V8_DIR/include/libplatform" ]; then
    rm -rf "$INSTALL_INCLUDE_DIR/libplatform"
    cp -a "$V8_DIR/include/libplatform" "$INSTALL_INCLUDE_DIR/"
fi
if [ -f "$V8_DIR/include/v8config.h" ]; then
    cp -fv "$V8_DIR/include/v8config.h" "$INSTALL_INCLUDE_DIR/"
fi

echo "=== V8 build/install complete ==="
