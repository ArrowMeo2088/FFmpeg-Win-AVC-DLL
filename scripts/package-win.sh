#!/usr/bin/env bash
# Collect runtime DLLs (FFmpeg + MinGW deps) into dist/bin for mpv / app bundling.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64}"
bin_dir="$dist_dir/mingw64/bin"

if [[ ! -d "$bin_dir" ]]; then
  echo "Expected install tree at $bin_dir"
  exit 1
fi

flat_dir="$dist_dir/bin"
mkdir -p "$flat_dir"

shopt -s nullglob
for pattern in \
  "$bin_dir"/avcodec-*.dll \
  "$bin_dir"/avformat-*.dll \
  "$bin_dir"/avutil-*.dll \
  "$bin_dir"/avfilter-*.dll \
  "$bin_dir"/swresample-*.dll \
  "$bin_dir"/swscale-*.dll \
  "$bin_dir"/ffmpeg.exe \
  "$bin_dir"/ffprobe.exe; do
  cp -f "$pattern" "$flat_dir/"
done

# Copy MinGW / libvpl runtime dependencies when dynamically linked.
if command -v ldd >/dev/null 2>&1; then
  mapfile -t deps < <(ldd "$flat_dir"/avcodec-*.dll 2>/dev/null | awk '/=>/ {print $3}' | sort -u)
  for dep in "${deps[@]}"; do
    [[ -z "$dep" || "$dep" == "not" ]] && continue
    case "$(basename "$dep")" in
      KERNEL32.dll|msvcrt.dll|ADVAPI32.dll|USER32.dll|WS2_32.dll|bcrypt.dll|Secur32.dll|CRYPT32.dll)
        continue
        ;;
    esac
    if [[ -f "$dep" ]]; then
      cp -f "$dep" "$flat_dir/"
    fi
  done
fi

cat >"$dist_dir/README.txt" <<EOF
FFmpeg Win x64 — Intel QSV (h264_qsv) + DASH/fMP4 minimal build
Built from: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)

Video: Intel iGPU hardware decode only (Quick Sync / libvpl). No H.264 software decoder.
Audio: AAC software decode.
Requires Intel GPU with QSV support and up-to-date graphics driver on the target PC.

Layout:
  bin/          Flat runtime bundle (DLL + ffmpeg.exe + ffprobe.exe)
  mingw64/      Full prefix (include/, lib/, bin/) for linking libmpv

Use with mpv:
  PKG_CONFIG_PATH=mingw64/lib/pkgconfig; mpv --hwdec=qsv
  Copy bin/*.dll (including libvpl) next to libmpv-2.dll

Bilibili playback notes:
  - Video/audio are often separate HTTPS fMP4 URLs (mov demuxer)
  - Set Referer / User-Agent in the player; FFmpeg handles byte-range streaming
  - Select H264 (AVC) representations; AAC for audio
EOF

echo "Packaged: $flat_dir"
