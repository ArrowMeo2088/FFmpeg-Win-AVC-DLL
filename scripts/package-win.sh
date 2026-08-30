#!/usr/bin/env bash
# Flat runtime bundle: FFmpeg libs + MinGW dependency closure (no System32 DLLs).
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

shopt -s nullglob
for pattern in \
  "$bin_dir"/avcodec-*.dll \
  "$bin_dir"/avformat-*.dll \
  "$bin_dir"/avutil-*.dll \
  "$bin_dir"/avfilter-*.dll \
  "$bin_dir"/swresample-*.dll \
  "$bin_dir"/swscale-*.dll; do
  cp -f "$pattern" "$flat_dir/"
done

declare -A queued=()
queue=()

enqueue() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local key
  key="$(basename "$f")"
  [[ -n "${queued[$key]:-}" ]] && return 0
  queued[$key]=1
  queue+=("$f")
}

for seed in "$flat_dir"/*.dll; do
  enqueue "$seed"
done

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
FFmpeg Win x64 — Intel QSV (h264_qsv) + DASH/fMP4 (DLL only)
Built from: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)

bin/          Runtime DLL bundle (mpv / embedding)
mingw64/      Dev prefix (include/, lib/pkgconfig/)
EOF

echo "Packaged: $flat_dir ($(ls -1 "$flat_dir" | wc -l) files)"
