# FFmpeg-Win-AVC-DLL

Windows x64 最小 FFmpeg：`h264_qsv`（Intel 核显）+ B 站 fMP4/DASH 流式。无 CLI（`--disable-programs`）。

## 链接方式（给 mpv）

| 组件 | 方式 |
|------|------|
| FFmpeg → libmpv | **静态** `.lib`（链进 libmpv） |
| libvpl | **动态** `libvpl.dll`（运行时随包分发） |
| libmpv → C# | 动态 DLL（由 MPV-Win-AVC 构建，本仓库不涉及） |

CPU 基线：**x86-64-v2**（`clang-cl` wrapper 注入 `-march=x86-64-v2`）。

## 已验证基线

以 Artifact **build #8**（MinGW 共享库）的 `configure` 功能集为准。

**不要**加 `--disable-protocol=udp,dtls`：`tls_schannel` 会链接 `ff_udp_*`，禁用 udp 会导致 `avformat` 链接失败。

## 构建（MSVC，本地）

```powershell
vcpkg install libvpl:x64-windows libxml2:x64-windows-static pkgconf:x64-windows

# 1) DevShell 导出环境
./scripts/ci-export-vcvars.ps1

# 2) MSYS2 CLANG64 shell
export VCPKG_ROOT='C:/vcpkg'
export PATH="/usr/bin:/clang64/bin:$PATH"
bash ./scripts/build-win-msvc.sh
```

产出：`dist/ffmpeg-win-msvc-x64/prefix/`（`.lib` + 头文件 + pkgconfig）、`dist/ffmpeg-win-msvc-x64/bin/libvpl.dll`。

## CI

1. `ci-export-vcvars.ps1` — DevShell 导出 `build/msvc-env.sh`
2. MSYS2 — `build-win-msvc.sh`（先 prepend `/usr/bin`，再编译）
3. 上传 Actions Artifact
