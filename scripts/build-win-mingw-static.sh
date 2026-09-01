#!/usr/bin/env bash
# MinGW static FFmpeg for mpv embedding.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64-static}"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64-static}"
prefix="${FFMPEG_PREFIX:-$dist_dir/prefix}"
jobs="${FFMPEG_JOBS:-$(nproc 2>/dev/null || echo 4)}"

export FFMPEG_BUILD_DIR="$build_dir"
export FFMPEG_DIST_DIR="$dist_dir"
export FFMPEG_PREFIX="$prefix"

mkdir -p "$(dirname "$prefix")"
prefix="$(cd "$(dirname "$prefix")" && pwd)/$(basename "$prefix")"
export FFMPEG_PREFIX="$prefix"

configure_script="$root_dir/scripts/configure-avc-dash-mingw-static.sh"
configure_stamp="$build_dir/.configure-avc-dash-mingw-static.stamp"
need_configure=0

if [[ "${FFMPEG_FORCE_RECONFIGURE:-0}" == "1" ]]; then
  need_configure=1
elif [[ ! -f "$build_dir/config.h" ]]; then
  need_configure=1
elif [[ ! -f "$configure_stamp" ]] || ! cmp -s "$configure_script" "$configure_stamp"; then
  need_configure=1
elif ! grep -q 'LIBXML_STATIC' "$build_dir/config.h" 2>/dev/null; then
  need_configure=1
fi

if [[ "$need_configure" == "1" ]]; then
  echo "=== Configure FFmpeg (LIBXML_STATIC static libxml2 ABI) ==="
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  bash "$configure_script"
  cp -f "$configure_script" "$configure_stamp"
else
  echo "=== Reusing existing configure in $build_dir ==="
fi

echo "=== Build (${jobs} jobs) ==="
make -C "$build_dir" -j"$jobs"

echo "=== Install to prefix ==="
rm -rf "$prefix"
make -C "$build_dir" install

bash "$root_dir/scripts/package-win-mingw-static.sh"

lib_dir="$prefix/lib"
bin_dir="$dist_dir/bin"
if [[ ! -d "$lib_dir" ]] || ! ls "$lib_dir"/*.a >/dev/null 2>&1; then
  echo "error: no static libs in $lib_dir" >&2
  exit 1
fi
if [[ ! -f "$bin_dir/libvpl-2.dll" ]]; then
  echo "error: missing $bin_dir/libvpl-2.dll" >&2
  exit 1
fi

echo "=== Done ==="
echo "Artifacts: $dist_dir"
ls -1 "$lib_dir"/*.a
ls -1 "$bin_dir"
