#!/usr/bin/env bash
# Dev prefix (static .lib + headers + pkg-config) + libvpl runtime DLL.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-msvc-x64}"
prefix="${FFMPEG_PREFIX:-$dist_dir/prefix}"
bin_dir="$dist_dir/bin"
vcpkg_root="${VCPKG_ROOT:-}"

if [[ ! -d "$prefix/lib" ]]; then
  echo "Expected install prefix at $prefix"
  exit 1
fi

if [[ -n "$vcpkg_root" ]] && command -v cygpath >/dev/null 2>&1; then
  vcpkg_root="$(cygpath -u "$vcpkg_root")"
fi

rm -rf "$bin_dir"
mkdir -p "$bin_dir"

if [[ -n "$vcpkg_root" ]]; then
  copied=0
  for candidate in \
    "$vcpkg_root/installed/x64-windows/bin/libvpl.dll" \
    "$vcpkg_root/installed/x64-windows/bin/vpl.dll"; do
    if [[ -f "$candidate" ]]; then
      cp -f "$candidate" "$bin_dir/"
      copied=1
      break
    fi
  done
  if [[ "$copied" -eq 0 ]]; then
    echo "error: libvpl.dll not found under $vcpkg_root/installed/x64-windows/bin"
    exit 1
  fi
fi

cat >"$dist_dir/README.txt" <<EOF
FFmpeg Win x64 MSVC — static libs for mpv + libvpl DLL
Built from: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)
CPU baseline: x86-64-v2 (SSE4.2)

prefix/       Headers, static .lib, pkg-config (link into libmpv)
bin/          Runtime: libvpl.dll only (FFmpeg is static inside mpv)

mpv / meson: set PKG_CONFIG_PATH to prefix/lib/pkgconfig
EOF

echo "Packaged prefix: $prefix"
echo "Runtime DLLs: $bin_dir ($(ls -1 "$bin_dir" 2>/dev/null | wc -l) files)"
