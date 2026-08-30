# FFmpeg-Win-AVC-DLL — 构建说明

面向 **哔哩哔哩类 DASH / 分轨 fMP4 流式播放** 的 Windows x64 最小化 FFmpeg 构建。

**视频仅 Intel 核显硬解（Quick Sync / `h264_qsv`），不含 H.264 软解，不含 NVIDIA/AMD 硬解路径。**

## 目标能力

| 能力 | 配置项 |
|------|--------|
| AVC 硬解（仅 Intel 核显） | `h264_qsv` + `--enable-libvpl`（oneVPL） |
| 音频（B 站主路径） | `aac` 软解（AAC 无 Intel QSV 解码路径） |
| 分轨 fMP4 URL | `mov` / `mp4` demuxer + `http`/`https` + byte-range |
| MPD / DASH | `dash` demuxer |
| 流式拖拽 | HTTPS Range + `mov` 解复用 |
| 给 mpv / 自研播放器用 | 共享库 DLL + `pkg-config` + 扁平 `bin/` 运行时包 |

**未包含**：H.264 软解、`h264_d3d11va` / `h264_dxva2`、NVIDIA CUVID、AMD AMF、HEVC/AV1、编码器、ffplay。

## 编译开关（`scripts/configure-avc-dash-win.sh`）

```bash
--enable-libvpl
--enable-decoder=h264_qsv
--disable-decoder=h264
--enable-decoder=aac,mp3
--enable-demuxer=dash,mov,mp4,aac,h264
--enable-parser=h264,hevc,aac,mpegaudio
--enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata
--enable-protocol=file,http,https,tcp,tls,pipe
--enable-schannel
--disable-openssl
```

### HTTPS / TLS

Windows 上 **SChannel 与 OpenSSL/GnuTLS 互斥**（FFmpeg `configure` 中 `schannel_conflict`）。本构建只用 `--enable-schannel`（系统证书库、无额外 TLS DLL），并显式 `--disable-openssl` 等，避免 MSYS2 自动探测到 OpenSSL 后冲突。

### 为何只用 QSV

1. **Intel 核显专用**：`h264_qsv` 走 Intel oneVPL（Quick Sync），不链接通用 D3D11VA/DXVA2 硬解（那些也会落到 NVIDIA/AMD 显卡上）。
2. **禁用软解**：显式 `--disable-decoder=h264`，避免回退到 CPU 解码。
3. **音频例外**：B 站音轨为 AAC，FFmpeg 无对应 Intel QSV 音频解码器，仍保留 `aac` 软解。
4. **运行时要求**：目标机器需 **Intel 核显/独显（带 QSV）** + 较新显卡驱动；无 Intel GPU 时视频无法解码。

## 本地构建（MSYS2 MINGW64）

```bash
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-pkg-config mingw-w64-x86_64-libvpl make diffutils

bash ./scripts/build-win.sh
```

产出：

- `dist/ffmpeg-win-x64/mingw64/` — 完整 prefix（含 `include/`、`lib/pkgconfig/`）
- `dist/ffmpeg-win-x64/bin/` — 扁平运行时（DLL + `ffmpeg.exe` + `ffprobe.exe` + `libvpl` 等依赖）

## GitHub Actions

推送至 `master` / `main` 后自动构建并上传 Artifact。

手动触发：`Actions → Build Windows x64 (AVC + DASH) → Run workflow`

## 与 mpv 配合

1. 用本仓库产物设置 `PKG_CONFIG_PATH` 指向 `mingw64/lib/pkgconfig`
2. mpv 播放参数示例：`--hwdec=qsv` 或 `--hwdec=auto-safe`（在仅 Intel 机器上）
3. 运行时将 `bin/` 下全部 DLL（含 `libvpl*.dll`）与 `libmpv-2.dll` 同目录

## 验证硬解配置

```bash
ffmpeg -hide_banner -decoders | grep h264
# 应仅有 h264_qsv，不应出现裸 h264 软解
```
