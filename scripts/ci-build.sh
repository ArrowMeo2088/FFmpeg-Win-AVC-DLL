#!/usr/bin/env bash
# CI entry: MSVC + MSYS2 in one shell (no pwsh/bash handoff).
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

export VCPKG_ROOT='C:/vcpkg'
export FFMPEG_DIST_DIR="$root_dir/dist/ffmpeg-win-msvc-x64"

if [[ -f /usr/bin/link.exe && ! -f /usr/bin/link.exe.bak ]]; then
  mv /usr/bin/link.exe /usr/bin/link.exe.bak
fi

source "$root_dir/scripts/ci-vcvars.sh"
export PATH="/usr/bin:/clang64/bin:${PATH}"

bash "$root_dir/scripts/build-win-msvc.sh"

lib_dir="$FFMPEG_DIST_DIR/prefix/lib"
bin_dir="$FFMPEG_DIST_DIR/bin"

if [[ ! -d "$lib_dir" ]]; then
  echo "error: missing $lib_dir" >&2
  exit 1
fi

if ! ls "$lib_dir"/*.lib >/dev/null 2>&1; then
  echo "error: no .lib files in $lib_dir" >&2
  exit 1
fi

if [[ ! -f "$bin_dir/libvpl.dll" ]]; then
  echo "error: missing $bin_dir/libvpl.dll" >&2
  exit 1
fi

echo "=== Build output ==="
ls -1 "$lib_dir"/*.lib
ls -1 "$bin_dir"
