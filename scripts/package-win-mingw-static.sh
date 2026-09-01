#!/usr/bin/env bash
# Dev prefix (static .a + headers + pkg-config) + libvpl runtime DLL.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${FFMPEG_DIST_DIR:-$root_dir/dist/ffmpeg-win-x64-static}"
prefix="${FFMPEG_PREFIX:-$dist_dir/prefix}"
bin_dir="$dist_dir/bin"
mingw_bin="${MINGW_PREFIX:-/mingw64}/bin"
build_dir="${FFMPEG_BUILD_DIR:-$root_dir/build/win-x64-static}"

if [[ ! -d "$prefix/lib" ]]; then
  echo "Expected install prefix at $prefix"
  exit 1
fi

rm -rf "$bin_dir"
mkdir -p "$bin_dir"

if [[ -f "$mingw_bin/libvpl-2.dll" ]]; then
  cp -f "$mingw_bin/libvpl-2.dll" "$bin_dir/"
else
  echo "error: libvpl-2.dll not found under $mingw_bin"
  exit 1
fi

{
  echo "# FFmpeg-Win-AVC-DLL static library manifest"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# commit: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  total=0
  while IFS= read -r f; do
    sz=$(stat -c%s "$f" 2>/dev/null || wc -c <"$f")
    total=$((total + sz))
    printf '%8d  %s\n' "$sz" "$(basename "$f")"
  done < <(find "$prefix/lib" -maxdepth 1 -name '*.a' | sort)
  echo "--------"
  printf 'total %d bytes (%.2f MiB)\n' "$total" "$(awk "BEGIN {printf \"%.2f\", $total/1024/1024}")"
} >"$dist_dir/MANIFEST.txt"

if [[ -f "$build_dir/ffbuild/config.log" ]]; then
  grep -E '^[[:space:]]*(--enable|--disable)' "$build_dir/ffbuild/config.log" \
    | head -n 200 >"$dist_dir/BUILDCONF.txt" || true
fi

cat >"$dist_dir/README.txt" <<EOF
FFmpeg Win x64 MinGW static — for mpv embedding
Built from: $(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)
CPU baseline: x86-64-v2 (SSE4.2)

prefix/       Headers, static .a, pkg-config (link into libmpv)
bin/          Runtime: libvpl-2.dll only (FFmpeg is static inside mpv)

mpv / meson: export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
EOF

echo "Packaged prefix: $prefix"
echo "Runtime DLLs: $bin_dir ($(ls -1 "$bin_dir" 2>/dev/null | wc -l) files)"

pc="$prefix/lib/pkgconfig/libavcodec.pc"
if [[ ! -f "$pc" ]]; then
  echo "error: missing $pc" >&2
  exit 1
fi
grep '^prefix=' "$pc"
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --modversion libavcodec

# Consumer links libvpl dynamically (libvpl-2.dll); strip from static .pc closure.
for pc in "$prefix/lib/pkgconfig"/*.pc; do
  sed -i 's/-lvpl//g; s/  / /g; s/ $//' "$pc"
done

# Preflight: DASH needs xml2 in static closure; vpl must NOT be static-linked.
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" PKG_CONFIG="pkg-config --static" \
  pkg-config --libs libavformat | grep -q -- '-lxml2'
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" PKG_CONFIG="pkg-config --static" \
  pkg-config --libs libavcodec | grep -qv -- '-lvpl'
echo "Static link preflight OK (libxml2 present, -lvpl stripped from .pc)"

avformat_a="$prefix/lib/libavformat.a"
if [[ ! -f "$avformat_a" ]]; then
  echo "error: missing $avformat_a" >&2
  exit 1
fi
if ! nm "$avformat_a" 2>/dev/null | grep -q ' U xmlFree'; then
  echo "error: libavformat.a missing undefined xmlFree (expected LIBXML_STATIC ABI)" >&2
  exit 1
fi
if nm "$avformat_a" 2>/dev/null | grep -q '__imp_xml'; then
  echo "error: libavformat.a still references __imp_xml* (rebuild with -DLIBXML_STATIC)" >&2
  exit 1
fi
echo "libavformat.a libxml2 ABI OK (xmlFree, no __imp_xml*)"
