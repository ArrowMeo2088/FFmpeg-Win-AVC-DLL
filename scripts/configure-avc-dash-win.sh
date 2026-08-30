#!/usr/bin/env bash
# Minimal FFmpeg configure for Bilibili-style streaming on Windows x64 (MSYS2 MINGW64).
# Video: Intel iGPU only via Quick Sync (h264_qsv + libvpl). No software H.264 decode.
# Audio: AAC software decode (Bilibili audio track; no Intel iGPU path for AAC).
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

  # Intel Quick Sync Video (oneVPL) — Intel iGPU hardware AVC decode only.
  --enable-libvpl
  --enable-decoder=h264_qsv
  --disable-decoder=h264

  # HTTPS streaming (Bilibili CDN).
  # TLS: Windows 原生 SChannel only — mutually exclusive with openssl/gnutls/mbedtls.
  --enable-protocol=file,http,https,tcp,tls,pipe
  --enable-schannel
  --disable-openssl
  --disable-gnutls
  --disable-libtls
  --disable-mbedtls

  # Containers: fragmented MP4 direct URLs + optional MPD.
  --enable-demuxer=dash,mov,mp4,aac,h264

  # Audio: software AAC (no QSV audio decoder for typical Bilibili streams).
  --enable-decoder=aac,mp3
  # hevc parser avoids link errors from shared H.264/HEVC SEI code paths in some FFmpeg versions.
  --enable-parser=h264,hevc,aac,mpegaudio

  # Required by h264_qsv (fMP4 bitstream conversion).
  --enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata

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

echo "=== FFmpeg configure (Intel QSV AVC + DASH/fMP4 + HTTPS) ==="
echo "Source : $root_dir"
echo "Build  : $build_dir"
echo "Prefix : $prefix"
"$root_dir/configure" "${conf[@]}"
