#!/usr/bin/env bash
# Collect runtime DLLs (FFmpeg + MinGW deps) into dist/bin for mpv / app bundling.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64}"
bin_dir="$dist_dir/mingw64/bin"
mingw_bin="${MINGW_PREFIX:-/mingw64}/bin"

if [[ ! -d "$bin_dir" ]]; then
  echo "Expected install tree at $bin_dir"
  exit 1
fi

flat_dir="$dist_dir/bin"
mkdir -p "$flat_dir"

copy_into_flat() {
  local src="$1"
  [[ -f "$src" ]] || return 0
  local dest="$flat_dir/$(basename "$src")"
  if [[ "$src" -ef "$dest" ]]; then
    return 0
  fi
  cp -f "$src" "$dest"
}

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
  copy_into_flat "$pattern"
done

# Known third-party runtime DLLs (not installed into our prefix by make install).
for pattern in \
  "$mingw_bin"/libvpl*.dll \
  "$mingw_bin"/libxml2*.dll \
  "$mingw_bin"/libwinpthread*.dll \
  "$mingw_bin"/libgcc_s*.dll \
  "$mingw_bin"/libstdc++*.dll; do
  for f in $pattern; do
    copy_into_flat "$f"
  done
done

# Copy remaining MinGW runtime deps reported by ldd (skip FFmpeg DLLs already present).
if command -v ldd >/dev/null 2>&1; then
  mapfile -t deps < <(ldd "$flat_dir"/avcodec-*.dll 2>/dev/null | awk '/=>/ {print $3}' | sort -u)
  for dep in "${deps[@]}"; do
    [[ -z "$dep" || "$dep" == "not" || ! -f "$dep" ]] && continue
    case "$(basename "$dep" | tr '[:upper:]' '[:lower:]')" in
      kernel32.dll|msvcrt.dll|advapi32.dll|user32.dll|ws2_32.dll|bcrypt.dll|secur32.dll|crypt32.dll|shell32.dll|ole32.dll|oleaut32.dll)
        continue
        ;;
      avcodec-*.dll|avformat-*.dll|avutil-*.dll|avfilter-*.dll|swresample-*.dll|swscale-*.dll)
        continue
        ;;
    esac
    copy_into_flat "$dep"
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
ls -la "$flat_dir"
