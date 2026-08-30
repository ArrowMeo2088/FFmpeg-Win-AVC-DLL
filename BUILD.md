# FFmpeg-Win-AVC-DLL

Windows x64 最小 FFmpeg 共享库：`h264_qsv`（Intel 核显）+ B 站 fMP4/DASH 流式。无 CLI（`--disable-programs`）。

## 已验证基线

以 Artifact **build #8** 的 `configure` 为准（能编过、能跑）。仅在此基础上：

- `--disable-programs`（去掉 ffmpeg/ffprobe）
- `--disable-avdevice`
- 去掉 `mp3` 解码

**不要**加 `--disable-protocol=udp,dtls`：`tls_schannel` 会链接 `ff_udp_*`，禁用 udp 会导致 `avformat` 链接失败。

## 构建

```bash
bash ./scripts/build-win.sh
```

产出：`dist/ffmpeg-win-x64/bin/`（DLL）、`dist/ffmpeg-win-x64/mingw64/`（开发用 prefix）。

## CI

推送后编译并上传 `dist/ffmpeg-win-x64/`，无 smoke/verify。
