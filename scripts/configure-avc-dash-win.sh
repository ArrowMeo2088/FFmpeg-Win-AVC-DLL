#!/usr/bin/env bash
# Minimal FFmpeg for Bilibili fMP4/DASH + Intel QSV (h264_qsv) on Windows x64.
# Output: shared libs + flat bin/ for mpv / embedding. No CLI tools.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64}"
prefix="${FFMPEG_PREFIX:-/mingw64}"

mkdir -p "$build_dir"
cd "$build_dir"

extra_cflags="${FFMPEG_EXTRA_CFLAGS:-}"
extra_ldflags="${FFMPEG_EXTRA_LDFLAGS:-}"

conf=(
  --prefix="$prefix"
  --arch=x86_64
  --target-os=mingw32
  --enable-shared
  --disable-static
  --disable-debug
  --disable-doc
  --enable-small
  --enable-version3

  --disable-everything
  --enable-avcodec
  --enable-avformat
  --enable-avutil
  --enable-swresample
  --enable-swscale
  --enable-avfilter
  --disable-avdevice

  --enable-w32threads
  --disable-pthreads

  # Intel iGPU AVC hardware decode only.
  --enable-libvpl
  --disable-libmfx
  --enable-decoder=h264_qsv
  --disable-decoder=h264

  # HTTPS streaming; SChannel only (not compatible with openssl/gnutls).
  --enable-protocol=file,http,https,tcp,tls,pipe
  --disable-protocol=udp,dtls
  --enable-schannel
  --disable-openssl
  --disable-gnutls
  --disable-libtls
  --disable-mbedtls

  --enable-libxml2

  # Bilibili: fMP4 (mov) + optional MPD (dash). No raw aac/h264 elementary streams.
  --enable-demuxer=dash,mov

  # Audio: AAC only (Bilibili audio track).
  --enable-decoder=aac
  --enable-parser=h264,hevc,aac

  --enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata

  # mpv / playback pipeline minimum.
  --enable-filter=aresample,aformat,abuffer,abuffersink,buffer,buffersink,format,null,scale

  # DLL-only; no ffmpeg/ffprobe/ffplay.
  --disable-programs
)

if [[ -n "$extra_cflags" ]]; then
  conf+=(--extra-cflags="$extra_cflags")
fi
if [[ -n "$extra_ldflags" ]]; then
  conf+=(--extra-ldflags="$extra_ldflags")
fi

echo "=== FFmpeg configure (Intel QSV AVC + DASH/fMP4 + HTTPS) ==="
echo "Source : $root_dir"
echo "Build  : $build_dir"
echo "Prefix : $prefix"
"$root_dir/configure" "${conf[@]}"
