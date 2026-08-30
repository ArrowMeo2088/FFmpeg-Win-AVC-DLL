# FFmpeg-Win-AVC-DLL — 构建说明

面向 **哔哩哔哩 fMP4/DASH 流式播放** 的 Windows x64 最小化 FFmpeg **共享库**构建（供 mpv / 自研播放器链接）。

**视频**：仅 Intel 核显 `h264_qsv`（oneVPL），无 H.264 软解。  
**音频**：仅 AAC 软解。  
**产出**：无 `ffmpeg` / `ffprobe` / `ffplay` / `libavdevice`。

## 当前裁剪（相对已验证的 build #8）

| 移除项 | 原因 |
|--------|------|
| `ffprobe` / `ffmpeg` / `ffplay` | `--disable-programs`，只要 DLL |
| `libavdevice` | 播放不需要采集设备 |
| `mp3` 解码 | B 站音轨为 AAC |
| `aac`/`h264` 裸流 demuxer | 实际走 `mov` / `dash` |
| `udp`/`dtls` 协议 | 未使用 |
| 多余 filter（`fps`/`trim`/`copy` 等） | 缩小体积；mpv 仍可用 scale/format 等 |

## 编译开关摘要

见 `scripts/configure-avc-dash-win.sh`。

## 本地构建（MSYS2 MINGW64）

```bash
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-pkg-config mingw-w64-x86_64-libvpl \
  mingw-w64-x86_64-libxml2 make diffutils

bash ./scripts/build-win.sh
```

产出：

- `dist/ffmpeg-win-x64/bin/` — 运行时 DLL（扁平，自包含 MinGW 依赖）
- `dist/ffmpeg-win-x64/mingw64/` — 链接用 prefix（`include/`、`lib/pkgconfig/`）

## GitHub Actions

推送后 **configure → 编译 → 打包 → 上传 Artifact**，无运行时校验。  
此前 CI 红字多为 **zip 未安装**（构建已成功）；已去掉多余 zip 步骤，只上传 `dist/ffmpeg-win-x64/`。

## 与 mpv 配合

1. `PKG_CONFIG_PATH` 指向 `mingw64/lib/pkgconfig`
2. 运行时将 `bin/` 下全部 DLL 与 `libmpv-2.dll` 同目录
3. 播放：`--hwdec=qsv`

## 本地自测（可选）

需在已安装 MSYS2 MinGW 的机器上，对**链接了本 DLL 的播放器**或临时拷贝的 `ffmpeg`（若自行开启 programs）测试；官方构建默认不含 CLI。
