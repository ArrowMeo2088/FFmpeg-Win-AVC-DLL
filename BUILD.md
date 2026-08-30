# FFmpeg-Win-AVC-DLL

Windows x64 最小 FFmpeg：`h264_qsv`（Intel 核显）+ B 站 fMP4/DASH 流式。无 CLI（`--disable-programs`）。

## 链接方式（给 mpv）

| 组件 | 方式 |
|------|------|
| FFmpeg → libmpv | **静态** `.lib`（链进 libmpv） |
| libvpl | **动态** `libvpl.dll`（运行时随包分发） |
| libmpv → C# | 动态 DLL（由 MPV-Win-AVC 构建，本仓库不涉及） |

CPU 基线：**x86-64-v2**（经 `clang-cl` wrapper 注入 `-march=x86-64-v2`；FFmpeg MSVC 过滤器会丢弃 `--extra-cflags` 里的 `-march`）。

## 已验证基线

以 Artifact **build #8**（MinGW 共享库）的 `configure` 功能集为准。MSVC 静态版保留相同编解码/协议开关。

**不要**加 `--disable-protocol=udp,dtls`：`tls_schannel` 会链接 `ff_udp_*`，禁用 udp 会导致 `avformat` 链接失败。

## 构建（MSVC，本地）

需：Visual Studio（含 **clang-cl**）、MSYS2 CLANG64（`make`/`nasm`）、vcpkg。

```powershell
vcpkg install libvpl:x64-windows libxml2:x64-windows-static pkgconf:x64-windows

# VS DevShell 中（脚本会自动设置 PKG_CONFIG / PKG_CONFIG_PATH）
bash ./scripts/build-win-msvc.sh
```

产出：

- `dist/ffmpeg-win-msvc-x64/prefix/` — `include/`、`lib/*.lib`、`lib/pkgconfig/`
- `dist/ffmpeg-win-msvc-x64/bin/libvpl.dll`

## CI

`windows-2025` + `C:\vcpkg` + MSYS2 CLANG64（`ci-build.sh` 内加载 `vcvars64`）；编译后上传 Actions Artifact。

## 旧 MinGW 共享库脚本（保留）

`scripts/build-win.sh` 为早期 DLL 方案，CI 已不再使用。
