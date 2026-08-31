#!/usr/bin/env bash
# MSVC static FFmpeg for mpv. CI: run ci-export-vcvars.ps1 first (pwsh/DevShell).
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/msvc-x64}"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-msvc-x64}"
prefix="${FFMPEG_PREFIX:-$dist_dir/prefix}"
jobs="${FFMPEG_JOBS:-${NUMBER_OF_PROCESSORS:-4}}"
msvc_env="${MSVC_ENV_FILE:-$root_dir/build/msvc-env.sh}"

export MSYSTEM="${MSYSTEM:-CLANG64}"
export FFMPEG_BUILD_DIR="$build_dir"
export FFMPEG_DIST_DIR="$dist_dir"
export FFMPEG_PREFIX="$prefix"
export PKG_CONFIG_MSVC_SYNTAX="${PKG_CONFIG_MSVC_SYNTAX:-1}"

# 1) MSVC toolchain (DevShell export in CI, or already in shell when building locally)
if [[ -f "$msvc_env" ]]; then
  # shellcheck disable=SC1090
  source "$msvc_env"
fi

# 2) MSYS tools MUST be prepended before any mv/make/bash call
export MSYS2_PATH_TYPE=inherit
export PATH="/usr/bin:/clang64/bin:${PATH:-}"

# 3) MSYS link.exe shadows MSVC link.exe
if [[ -f /usr/bin/link.exe && ! -f /usr/bin/link.exe.bak ]]; then
  /usr/bin/mv -f /usr/bin/link.exe /usr/bin/link.exe.bak
fi

if [[ -z "${CLANG_CL:-}" || ! -f "$CLANG_CL" ]]; then
  echo "error: CLANG_CL not set or missing; run ci-export-vcvars.ps1 first" >&2
  echo "CLANG_CL=${CLANG_CL:-}" >&2
  exit 1
fi
if [[ ! -x /usr/bin/make ]]; then
  echo "error: /usr/bin/make not found" >&2
  exit 1
fi
if [[ ! -x /usr/bin/nasm ]]; then
  echo "error: /usr/bin/nasm not found" >&2
  exit 1
fi

setup_vcpkg_env() {
  local root='C:/vcpkg'
  export VCPKG_ROOT="$root"
  export PKG_CONFIG="${root}/installed/x64-windows/tools/pkgconf/pkgconf.exe"
  export PKG_CONFIG_PATH="${root}/installed/x64-windows/lib/pkgconfig;${root}/installed/x64-windows-static/lib/pkgconfig"

  if [[ ! -f "$PKG_CONFIG" ]]; then
    echo "error: vcpkg pkgconf not found: $PKG_CONFIG" >&2
    exit 1
  fi
  if ! "$PKG_CONFIG" --exists 'vpl >= 2.6'; then
    echo "error: libvpl pkg-config check failed" >&2
    "$PKG_CONFIG" --print-errors 'vpl >= 2.6' || true
    exit 1
  fi
  if ! "$PKG_CONFIG" --exists libxml-2.0; then
    echo "error: libxml2 pkg-config check failed" >&2
    "$PKG_CONFIG" --print-errors libxml-2.0 || true
    exit 1
  fi
}

setup_vcpkg_env

# 4) x86-64-v2 via compiler wrapper (FFmpeg MSVC filter drops -march=*)
wrapper_dir="$build_dir/wrappers"
mkdir -p "$wrapper_dir"
cat >"$wrapper_dir/clang-cl-v2" <<EOF
#!/usr/bin/env bash
exec "$CLANG_CL" -march=x86-64-v2 "\$@"
EOF
chmod +x "$wrapper_dir/clang-cl-v2"
export CC="$wrapper_dir/clang-cl-v2"
export CXX="$wrapper_dir/clang-cl-v2"

# 5) configure → build → install → package
bash "$root_dir/scripts/configure-avc-dash-msvc.sh"

echo "=== Build (${jobs} jobs) ==="
cd "$build_dir"
make -j"$jobs"

echo "=== Install to dist prefix ==="
rm -rf "$prefix"
make install

bash "$root_dir/scripts/package-win-msvc.sh"

# 6) verify artifact layout before CI upload
lib_dir="$dist_dir/prefix/lib"
bin_dir="$dist_dir/bin"
if [[ ! -d "$lib_dir" ]] || ! ls "$lib_dir"/*.lib >/dev/null 2>&1; then
  echo "error: no static libs in $lib_dir" >&2
  exit 1
fi
if [[ ! -f "$bin_dir/libvpl.dll" ]]; then
  echo "error: missing $bin_dir/libvpl.dll" >&2
  exit 1
fi

echo "=== Done ==="
echo "Artifacts: $dist_dir"
ls -1 "$lib_dir"/*.lib
ls -1 "$bin_dir"
