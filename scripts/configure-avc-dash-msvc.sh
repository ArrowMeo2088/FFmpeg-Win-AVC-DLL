#!/usr/bin/env bash
# MSVC static libs for mpv (libvpl stays a runtime DLL).
# Feature set matches validated MinGW build #8 baseline.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/msvc-x64}"
prefix="${FFMPEG_PREFIX:-$root_dir/dist/ffmpeg-win-msvc-x64/prefix}"

mkdir -p "$build_dir"
cd "$build_dir"

conf=(
  --prefix="$prefix"
  --toolchain=msvc
  --arch=x86_64
  --target-os=win64
  --enable-static
  --disable-shared
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

if [[ -n "${CC:-}" ]]; then
  conf+=(--cc="$CC")
fi
if [[ -n "${CXX:-}" ]]; then
  conf+=(--cxx="$CXX")
fi
if [[ -n "${PKG_CONFIG:-}" ]]; then
  conf+=(--pkg-config="$PKG_CONFIG")
fi

"$root_dir/configure" "${conf[@]}"
