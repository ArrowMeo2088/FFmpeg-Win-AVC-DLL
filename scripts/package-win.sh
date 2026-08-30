#!/usr/bin/env bash
# Flat runtime bundle: install prefix + MinGW DLL closure (never copy System32 DLLs).
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64}"
bin_dir="$dist_dir/mingw64/bin"
mingw_bin="${MINGW_PREFIX:-/mingw64}/bin"
flat_dir="$dist_dir/bin"

if [[ ! -d "$bin_dir" ]]; then
  echo "Expected install tree at $bin_dir"
  exit 1
fi

rm -rf "$flat_dir"
mkdir -p "$flat_dir"
cp -f "$bin_dir"/*.dll "$bin_dir"/*.exe "$flat_dir"/ 2>/dev/null || true

declare -A queued=()
queue=("$flat_dir/ffmpeg.exe")

enqueue() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local key
  key="$(basename "$f")"
  [[ -n "${queued[$key]:-}" ]] && return 0
  queued[$key]=1
  queue+=("$f")
}

while ((${#queue[@]} > 0)); do
  current="${queue[0]}"
  queue=("${queue[@]:1}")
  while read -r dep; do
    [[ -n "$dep" && -f "$dep" ]] || continue
    [[ "$dep" == "$mingw_bin/"* ]] || continue
    local_name="$(basename "$dep")"
    dest="$flat_dir/$local_name"
    if [[ ! -f "$dest" ]]; then
      cp -f "$dep" "$dest"
    fi
    enqueue "$dest"
  done < <(ldd "$current" 2>/dev/null | awk '/=>/ {print $3}')
done

cat >"$dist_dir/README.txt" <<EOF
FFmpeg Win x64 — Intel QSV (h264_qsv) + DASH/fMP4 minimal build
Built from: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)

Video: Intel iGPU hardware decode only (Quick Sync / libvpl). No H.264 software decoder.
Audio: AAC software decode.

Layout:
  bin/          Self-contained runtime (copy this folder as a whole)
  mingw64/      Dev prefix (include/, lib/pkgconfig/) for linking libmpv
EOF

echo "Packaged: $flat_dir ($(ls -1 "$flat_dir" | wc -l) files)"
