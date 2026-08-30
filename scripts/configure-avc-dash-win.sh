#!/usr/bin/env bash
# Proven minimal config (validated artifact build #8) + DLL-only output.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64}"
prefix="${FFMPEG_PREFIX:-/mingw64}"

mkdir -p "$build_dir"
cd "$build_dir"

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

  --enable-libvpl
  --disable-libmfx
  --enable-decoder=h264_qsv
  --disable-decoder=h264

  # Do NOT disable udp/dtls: tls_schannel.o links ff_udp_* symbols.
  --enable-protocol=file,http,https,tcp,tls,pipe
  --enable-schannel
  --disable-openssl
  --disable-gnutls
  --disable-libtls
  --disable-mbedtls

  --enable-libxml2
  --enable-demuxer=dash,mov,mp4,aac,h264
  --enable-decoder=aac
  --enable-parser=h264,hevc,aac

  --enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata
  --enable-filter=aresample,aformat,abuffer,abuffersink,buffer,buffersink,format,null,scale,setpts,fps,trim,copy

  --disable-programs
)

"$root_dir/configure" "${conf[@]}"
