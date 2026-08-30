# FFmpeg-Win-AVC-DLL — 构建说明

面向 **哔哩哔哩类 DASH / 分轨 fMP4 流式播放** 的 Windows x64 最小化 FFmpeg 构建。

## 目标能力

| 能力 | 配置项 |
|------|--------|
| AVC (H.264) 软/硬解 | `h264` decoder + `h264_d3d11va` / `h264_dxva2` |
| 音频（B 站主路径） | `aac` decoder（附带 `mp3` 兜底） |
| 分轨 fMP4 URL | `mov` / `mp4` demuxer + `http`/`https` + byte-range |
| MPD / DASH | `dash` demuxer |
| 流式拖拽 | 依赖 HTTPS Range，由 `http` 协议与 `mov` 解复用实现 |
| 给 mpv / 自研播放器用 | 共享库 DLL + `pkg-config` + 扁平 `bin/` 运行时包 |

**未包含**：HEVC/AV1 解码、编码器、ffplay、设备采集、大量滤镜与格式。

## 编译开关（`scripts/configure-avc-dash-win.sh`）

核心思路：`--disable-everything` 后按白名单启用组件。

```bash
--enable-avcodec --enable-avformat --enable-avutil
--enable-swresample --enable-swscale --enable-avfilter
--enable-protocol=file,http,https,tcp,tls,pipe,crypto
--enable-schannel --enable-openssl
--enable-demuxer=dash,mov,mp4,aac,h264
--enable-decoder=h264,aac,mp3
--enable-parser=h264,hevc,aac,mpegaudio
--enable-bsf=h264_mp4toannexb,aac_adtstoasc,extract_extradata
--enable-hwaccel=h264_d3d11va,h264_dxva2
--enable-ffmpeg --enable-ffprobe --disable-ffplay
```

### 为何这样选

1. **B 站常见形态**：两个 HTTPS fMP4 地址（视频 + 音频），不是单一文件；`mov` 比 `dash` 更常用，`dash` 留给 MPD。
2. **Referer / UA**：在播放器层设置 HTTP 头；FFmpeg 负责 Range 请求与解封装。
3. **`hevc` parser**：部分 FFmpeg 版本里 H.264 与 HEVC 共用 SEI 代码，仅开 `h264` parser 可能链接失败（参见 [ffmpeg-mini](https://github.com/DMXCore/ffmpeg-mini) 说明）。
4. **`swscale` / `swresample` / `avfilter`**：libmpv 链接需要；滤镜只开播放链路最小集合。

## 本地构建（MSYS2 MINGW64）

```bash
# 在 MINGW64 shell 中，仓库根目录：
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-pkg-config mingw-w64-x86_64-openssl make diffutils

bash ./scripts/build-win.sh
```

产出：

- `dist/ffmpeg-win-x64/mingw64/` — 完整 prefix（含 `include/`、`lib/pkgconfig/`）
- `dist/ffmpeg-win-x64/bin/` — 扁平运行时（DLL + `ffmpeg.exe` + `ffprobe.exe`）

## GitHub Actions

推送至 `master` / `main` 后，`.github/workflows/build-win.yml` 自动：

1. MSYS2 MINGW64 环境配置、编译、安装  
2. 打包扁平 `bin/` 与完整 prefix  
3. 上传 Artifact（Actions 页下载）

手动触发：`Actions → Build Windows x64 (AVC + DASH) → Run workflow`

## 与 mpv 配合

1. 先构建本仓库，取得 `dist/ffmpeg-win-x64/mingw64/lib/pkgconfig/*.pc`
2. 构建 `MPV-Win-AVC` 时设置 `PKG_CONFIG_PATH` 指向该目录
3. 运行时将 `bin/` 下全部 DLL 与 `libmpv-2.dll` 放在同一目录

## 调整建议

| 需求 | 修改 |
|------|------|
| 再缩小体积 | 去掉 `mp3` decoder、`--disable-ffprobe`、减少 filter 列表 |
| 只要软解 | 去掉 `d3d11va` / `dxva2` 相关选项 |
| 要接 MPD 更多特性 | 视情况增加 `crypto` / `xml` 相关依赖（当前已开 `crypto` protocol） |
