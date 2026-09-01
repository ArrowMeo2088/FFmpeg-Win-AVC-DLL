#!/usr/bin/env bash
# MinGW static libs for mpv (libvpl stays a runtime DLL).
# Feature set matches validated MinGW build #8 / MSVC static baseline.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64-static}"
prefix="${FFMPEG_PREFIX:-$root_dir/dist/ffmpeg-win-x64-static/prefix}"

mkdir -p "$(dirname "$prefix")" "$build_dir"
prefix="$(cd "$(dirname "$prefix")" && pwd)/$(basename "$prefix")"
export FFMPEG_PREFIX="$prefix"
cd "$build_dir"

conf=(
  --prefix="$prefix"
  --arch=x86_64
  --target-os=mingw32
  --enable-static
  --disable-shared
  --disable-debug
  --disable-doc
  --enable-small
  --enable-version3
  --extra-cflags=-march=x86-64-v2

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
  --enable-parser=h264,aac

  --enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata
  --enable-filter=aresample,aformat,abuffer,abuffersink,buffer,buffersink,format,null,scale,setpts,fps,trim,copy

  --disable-programs
)

"$root_dir/configure" "${conf[@]}"
