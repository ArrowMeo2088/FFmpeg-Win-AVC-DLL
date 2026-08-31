#!/usr/bin/env bash
# Load MSVC x64 toolchain into the current MSYS2 shell.
set -euo pipefail

if command -v clang-cl >/dev/null 2>&1; then
  exit 0
fi

VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
if [[ ! -f "$VSWHERE" ]]; then
  echo "error: vswhere not found: $VSWHERE" >&2
  exit 1
fi

VSPATH="$("$VSWHERE" -latest -products '*' \
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
  -property installationPath | tr -d '\r\n')"

if [[ -z "$VSPATH" ]]; then
  echo "error: Visual Studio installation not found" >&2
  exit 1
fi

VCVARS="${VSPATH}\\VC\\Auxiliary\\Build\\vcvars64.bat"

while IFS= read -r line; do
  case "$line" in
    PATH=*|INCLUDE=*|LIB=*|LIBPATH=*|WindowsSdkDir=*|WindowsSDKLibVersion=*|VCToolsInstallDir=*|VSINSTALLDIR=*|UniversalCRTSdkDir=*|VSCMD_ARG_TGT_ARCH=*)
      export "$line"
      ;;
  esac
done < <(MSYS2_ARG_CONV_EXCL='*' cmd //c "call \"${VCVARS}\" >nul 2>&1 && set" | tr -d '\r')

if ! command -v clang-cl >/dev/null 2>&1; then
  echo "error: clang-cl not available after vcvars64" >&2
  exit 1
fi
