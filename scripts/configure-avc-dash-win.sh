#!/usr/bin/env bash
# Minimal FFmpeg configure for Bilibili-style streaming on Windows x64 (MSYS2 MINGW64).
# Scope: AVC decode + AAC audio + fMP4/DASH demux + HTTPS byte-range streaming.
# Intended consumers: libmpv, custom .NET players, ffmpeg/ffprobe CLI for debugging.
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

  # Strip default feature set, then enable only what we need.
  --disable-everything
  --enable-avcodec
  --enable-avformat
  --enable-avutil
  --enable-swresample
  --enable-swscale
  --enable-avfilter

  # HTTPS streaming (Bilibili CDN); schannel is native on Windows, openssl is fallback.
  --enable-protocol=file,http,https,tcp,tls,pipe,crypto
  --enable-schannel
  --enable-openssl

  # Containers: fragmented MP4 direct URLs + optional MPD.
  --enable-demuxer=dash,mov,mp4,aac,h264

  # Video: AVC only. Audio: AAC (primary on Bilibili) + MP3 fallback.
  --enable-decoder=h264,aac,mp3
  # hevc parser avoids link errors from shared H.264/HEVC SEI code paths in some FFmpeg versions.
  --enable-parser=h264,hevc,aac,mpegaudio

  # fMP4 / ADTS helpers used when remuxing or feeding decoders.
  --enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata

  # Windows hardware AVC decode (optional at runtime).
  --enable-d3d11va
  --enable-dxva2
  --enable-hwaccel=h264_d3d11va,h264_dxva2

  # Minimal libavfilter set for playback pipelines / libmpv linkage.
  --enable-filter=aresample,aformat,abuffer,abuffersink,buffer,buffersink,format,null,scale,setpts,fps,trim,copy

  # CLI tools (no ffplay).
  --enable-ffmpeg
  --enable-ffprobe
  --disable-ffplay

  --enable-pthreads
)

if [[ -n "$extra_cflags" ]]; then
  conf+=(--extra-cflags="$extra_cflags")
fi
if [[ -n "$extra_ldflags" ]]; then
  conf+=(--extra-ldflags="$extra_ldflags")
fi

echo "=== FFmpeg configure (AVC + DASH/fMP4 + HTTPS) ==="
echo "Source : $root_dir"
echo "Build  : $build_dir"
echo "Prefix : $prefix"
"$root_dir/configure" "${conf[@]}"
