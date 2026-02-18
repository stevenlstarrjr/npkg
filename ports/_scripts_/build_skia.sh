#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRDPARTY_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$SCRIPT_DIR/deps"
SKIA_DIR="$DEPS_DIR/skia"
DEPOT_TOOLS_DIR="$DEPS_DIR/depot_tools"
BUILD_DIR="$SCRIPT_DIR/build_skia"
INSTALL_DIR="$THIRDPARTY_DIR"

echo "=== Building Skia (Vulkan, SKSG, SVG) with clang + libc++ ==="

if ! command -v clang >/dev/null 2>&1 || ! command -v clang++ >/dev/null 2>&1; then
    echo "clang/clang++ not found"
    exit 1
fi
if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    mkdir -p "$DEPS_DIR"
    cd "$DEPS_DIR"
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

export PATH="$DEPOT_TOOLS_DIR:$PATH"

# Bootstrap depot_tools (ensures python3_bin_reldir.txt exists)
if [ -x "$DEPOT_TOOLS_DIR/update_depot_tools" ]; then
    "$DEPOT_TOOLS_DIR/update_depot_tools" >/dev/null
fi
if [ -x "$DEPOT_TOOLS_DIR/ensure_bootstrap" ]; then
    "$DEPOT_TOOLS_DIR/ensure_bootstrap" >/dev/null
fi
if [ ! -f "$DEPOT_TOOLS_DIR/python3_bin_reldir.txt" ] && command -v gclient >/dev/null 2>&1; then
    gclient --version >/dev/null
fi

if ! command -v gn >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
    echo "gn or ninja not found in PATH (install depot_tools)"
    exit 1
fi

if [ ! -d "$SKIA_DIR" ]; then
    mkdir -p "$DEPS_DIR"
    cd "$DEPS_DIR"
    git clone --depth 1 https://skia.googlesource.com/skia
fi

cd "$SKIA_DIR"
python3 tools/git-sync-deps
python3 bin/fetch-ninja

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cat > "$BUILD_DIR/args.gn" <<'EOF'
is_official_build = true
is_component_build = false
cc = "clang"
cxx = "clang++"
skia_use_vulkan = true
skia_use_gl = false
skia_use_dawn = false
skia_use_x11 = true
skia_enable_svg = true
skia_enable_skottie = true
skia_enable_skparagraph = true
skia_enable_skshaper = true
skia_use_freetype = true
skia_use_harfbuzz = true
skia_use_icu = true
skia_use_expat = true
skia_use_libpng_decode = true
skia_use_libpng_encode = true
skia_use_libjpeg_turbo_decode = true
skia_use_libjpeg_turbo_encode = true
skia_use_libwebp_decode = true
skia_use_libwebp_encode = true
extra_cflags = [ "-stdlib=libc++" ]
extra_ldflags = [ "-stdlib=libc++", "-lc++abi" ]
EOF

gn gen "$BUILD_DIR" --args="$(cat "$BUILD_DIR/args.gn")"
ninja -C "$BUILD_DIR"

echo "=== Installing Skia ==="
mkdir -p "$INSTALL_DIR/lib/x86_64"
mkdir -p "$INSTALL_DIR/include/skia"

cp -v "$BUILD_DIR"/libskia.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libsksg.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libsvg.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libskottie.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libskparagraph.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libskshaper.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libskunicode_core.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libskunicode_icu.a "$INSTALL_DIR/lib/x86_64/"

# Common Skia deps that Skia static lib may reference
cp -v "$BUILD_DIR"/libskcms.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libwuffs.a "$INSTALL_DIR/lib/x86_64/"
cp -v "$BUILD_DIR"/libzlib.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libjpeg.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libpng.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libwebp.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libexpat.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libjsonreader.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libskresources.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libbentleyottmann.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libcompression_utils_portable.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libdng_sdk.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true
cp -v "$BUILD_DIR"/libpiex.a "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || true

cp -a "$SKIA_DIR/include" "$INSTALL_DIR/include/skia/"
cp -a "$SKIA_DIR/modules/skottie/include" "$INSTALL_DIR/include/skia/"
cp -a "$SKIA_DIR/modules/skparagraph/include" "$INSTALL_DIR/include/skia/"
cp -a "$SKIA_DIR/modules/skshaper/include" "$INSTALL_DIR/include/skia/"
cp -a "$SKIA_DIR/modules/svg/include" "$INSTALL_DIR/include/skia/"

echo "=== Skia installed to $INSTALL_DIR ==="
