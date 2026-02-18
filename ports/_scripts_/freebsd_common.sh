#!/bin/sh
set -eu

pkg_jobs() {
  if [ -n "${PKG_JOBS:-}" ]; then
    echo "${PKG_JOBS}"
    return
  fi
  if command -v sysctl >/dev/null 2>&1; then
    n="$(sysctl -n hw.ncpu 2>/dev/null || true)"
    if [ -n "$n" ]; then
      echo "$n"
      return
    fi
  fi
  if command -v getconf >/dev/null 2>&1; then
    n="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    if [ -n "$n" ]; then
      echo "$n"
      return
    fi
  fi
  echo 1
}

pkg_require_env() {
  var="$1"
  eval "val=\${$var:-}"
  if [ -z "$val" ]; then
    echo "missing required env: $var" >&2
    exit 1
  fi
}

pkg_require_cmd() {
  cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
}

pkg_init() {
  pkg_require_env PKG_NAME
  pkg_require_env PKG_VERSION
  pkg_require_env PKG_SRC_DIR
  pkg_require_env PKG_BUILD_DIR
  pkg_require_env PKG_STORE_DIR
  JOBS="$(pkg_jobs)"
  export JOBS
  mkdir -p "$PKG_BUILD_DIR" "$PKG_STORE_DIR"
}
