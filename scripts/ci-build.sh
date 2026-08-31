#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

export VCPKG_ROOT='C:/vcpkg'
export FFMPEG_DIST_DIR="$root_dir/dist/ffmpeg-win-msvc-x64"
export MSYS2_PATH_TYPE=inherit

env_file="$root_dir/build/msvc-env.sh"
if [[ ! -f "$env_file" ]]; then
  echo "error: missing $env_file (run ci-export-vcvars.ps1 first)" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$env_file"

if [[ -f /usr/bin/link.exe && ! -f /usr/bin/link.exe.bak ]]; then
  mv /usr/bin/link.exe /usr/bin/link.exe.bak
fi

export PATH="/usr/bin:/clang64/bin:${PATH}"

if ! command -v clang-cl >/dev/null 2>&1; then
  echo "error: clang-cl not in PATH after sourcing MSVC environment" >&2
  exit 1
fi

bash "$root_dir/scripts/build-win-msvc.sh"

lib_dir="$FFMPEG_DIST_DIR/prefix/lib"
bin_dir="$FFMPEG_DIST_DIR/bin"

if [[ ! -d "$lib_dir" ]] || ! ls "$lib_dir"/*.lib >/dev/null 2>&1; then
  echo "error: no static libs in $lib_dir" >&2
  exit 1
fi

if [[ ! -f "$bin_dir/libvpl.dll" ]]; then
  echo "error: missing $bin_dir/libvpl.dll" >&2
  exit 1
fi

echo "=== Build output ==="
ls -1 "$lib_dir"/*.lib
ls -1 "$bin_dir"
