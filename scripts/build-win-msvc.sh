#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/msvc-x64}"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-msvc-x64}"
prefix="${FFMPEG_PREFIX:-$dist_dir/prefix}"
jobs="${FFMPEG_JOBS:-${NUMBER_OF_PROCESSORS:-4}}"

export MSYSTEM="${MSYSTEM:-CLANG64}"
export FFMPEG_BUILD_DIR="$build_dir"
export FFMPEG_DIST_DIR="$dist_dir"
export FFMPEG_PREFIX="$prefix"
export PKG_CONFIG_MSVC_SYNTAX="${PKG_CONFIG_MSVC_SYNTAX:-1}"

setup_vcpkg_env() {
  local root="${VCPKG_ROOT:-C:/vcpkg}"
  root="${root//\\//}"

  export PKG_CONFIG="${root}/installed/x64-windows/tools/pkgconf/pkgconf.exe"
  # Windows pkgconf uses ';' between entries. Do NOT use --static globally: libvpl is dynamic.
  export PKG_CONFIG_PATH="${root}/installed/x64-windows/lib/pkgconfig;${root}/installed/x64-windows-static/lib/pkgconfig"

  if [[ ! -f "$PKG_CONFIG" ]]; then
    echo "error: vcpkg pkgconf not found: $PKG_CONFIG"
    exit 1
  fi

  if ! "$PKG_CONFIG" --exists 'vpl >= 2.6'; then
    echo "error: libvpl pkg-config check failed"
    "$PKG_CONFIG" --print-errors 'vpl >= 2.6' || true
    echo "PKG_CONFIG=$PKG_CONFIG"
    echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
    exit 1
  fi

  if ! "$PKG_CONFIG" --exists libxml-2.0; then
    echo "error: libxml2 pkg-config check failed"
    "$PKG_CONFIG" --print-errors libxml-2.0 || true
    exit 1
  fi
}

ensure_tool() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1 && return 0
  local dir
  for dir in \
    /usr/bin \
    /clang64/bin \
    /mingw64/bin \
    "/c/Program Files/NASM"; do
    if [[ -x "$dir/$tool" || -x "$dir/$tool.exe" ]]; then
      export PATH="$dir:$PATH"
      command -v "$tool" >/dev/null 2>&1 && return 0
    fi
  done
  echo "error: required tool not in PATH: $tool"
  exit 1
}

setup_vcpkg_env
ensure_tool clang-cl
ensure_tool nasm
ensure_tool make

# MSYS link.exe shadows MSVC link.exe when both are on PATH.
if [[ -f /usr/bin/link.exe && ! -f /usr/bin/link.exe.bak ]]; then
  mv /usr/bin/link.exe /usr/bin/link.exe.bak
fi

# FFmpeg's MSVC cflags filter drops -march=*. Bake x86-64-v2 into the compiler.
wrapper_dir="$build_dir/wrappers"
mkdir -p "$wrapper_dir"
cat >"$wrapper_dir/clang-cl-v2" <<'EOF'
#!/usr/bin/env bash
exec clang-cl -march=x86-64-v2 "$@"
EOF
chmod +x "$wrapper_dir/clang-cl-v2"
export CC="$wrapper_dir/clang-cl-v2"
export CXX="$wrapper_dir/clang-cl-v2"

bash "$root_dir/scripts/configure-avc-dash-msvc.sh"

echo "=== Build (${jobs} jobs) ==="
cd "$build_dir"
make -j"$jobs"

echo "=== Install to dist prefix ==="
rm -rf "$prefix"
make install

bash "$root_dir/scripts/package-win-msvc.sh"

echo "=== Done ==="
echo "Artifacts: $dist_dir"
