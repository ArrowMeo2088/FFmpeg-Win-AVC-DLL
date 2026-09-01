# FFmpeg-Win-AVC-DLL

Windows x64 最小 FFmpeg：`h264_qsv`（Intel 核显）+ B 站 fMP4/DASH 流式。无 CLI（`--disable-programs`）。

## 功能边界（Bili.NetF / mpv-kernel）

| 启用 | 禁用 |
|------|------|
| `h264_qsv`（libvpl） | H.264 软解、NV/AMD/DXVA |
| AAC 软解 | 其他音视频 codec |
| DASH / mov / fMP4 | RTMP、UDP 播放等 |
| HTTP/HTTPS（+ tcp/tls/pipe/file） | OpenSSL/GnuTLS |
| libxml2（DASH manifest） | ffmpeg/ffplay CLI |

**注意**：不要 `--disable-protocol=udp`；`tls_schannel` 会链接 `ff_udp_*` 内部符号。

## 链接方式（给 mpv）

| 组件 | 方式 |
|------|------|
| FFmpeg → libmpv | **静态** `.a`（链进 libmpv-2.dll） |
| libvpl | **动态** `libvpl-2.dll`（`h264_qsv` 运行时） |
| libxml2 | **静态**（随 libavformat DASH 链入 libmpv；meson 须显式 `dependency('libxml-2.0', static: true)`） |

`package-win-mingw-static.sh` 会从 prefix 的 `.pc` 中剥离 `-lvpl`，避免 `pkg-config --static` 误链 `libvpl.a`（C++ 静态库）。mpv 侧须用 `cc.find_library('vpl', static: false)` 动态链接。

CPU 基线：**x86-64-v2**（`-march=x86-64-v2`）。

## 主构建路径（MSYS2 MINGW64 静态）

```bash
# MSYS2 MINGW64 shell
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-pkgconf mingw-w64-x86_64-libvpl mingw-w64-x86_64-libxml2 make

cd /path/to/FFmpeg-Win-AVC-DLL
bash ./scripts/build-win-mingw-static.sh
```

产出：`dist/ffmpeg-win-x64-static/`

- `prefix/include/`、`prefix/lib/*.a`、`prefix/lib/pkgconfig/`
- `bin/libvpl-2.dll`
- `MANIFEST.txt`、`BUILDCONF.txt`

mpv 构建时：

```bash
export PKG_CONFIG_PATH=/path/to/dist/ffmpeg-win-x64-static/prefix/lib/pkgconfig
```

## 其他脚本

| 脚本 | 用途 |
|------|------|
| `build-win-mingw-static.sh` | **主路径**：MinGW 静态，给 mpv |
| `build-win.sh` | 共享 DLL 调试包（deprecated） |
| `build-win-msvc.sh` | MSVC 静态（附录，需 vcpkg） |

## CI

`.github/workflows/build-win.yml`：MSYS2 MINGW64 静态构建，上传 `dist/ffmpeg-win-x64-static/`。

## 附录：MSVC 静态（可选）

见 `scripts/build-win-msvc.sh` 与 `scripts/ci-export-vcvars.ps1`（需 vcpkg libvpl/libxml2）。
