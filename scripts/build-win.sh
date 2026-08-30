#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64}"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64}"
jobs="${FFMPEG_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

export FFMPEG_BUILD_DIR="$build_dir"
export FFMPEG_DIST_DIR="$dist_dir"

bash "$root_dir/scripts/configure-avc-dash-win.sh"

echo "=== Build (${jobs} jobs) ==="
make -C "$build_dir" -j"$jobs"

echo "=== Install to dist ==="
rm -rf "$dist_dir"
DESTDIR="$dist_dir" make -C "$build_dir" install

bash "$root_dir/scripts/package-win.sh"

echo "=== Done ==="
echo "Artifacts: $dist_dir"
