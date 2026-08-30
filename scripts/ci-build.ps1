$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

Set-Location $env:GITHUB_WORKSPACE

$dist = Join-Path $env:GITHUB_WORKSPACE 'dist\ffmpeg-win-msvc-x64'
$env:FFMPEG_DIST_DIR = $dist

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw 'Visual Studio not found' }

Import-Module "$vsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=amd64 -host_arch=amd64'

$env:PATH = @(
  'C:\msys64\clang64\bin',
  'C:\msys64\usr\bin',
  'C:\Program Files\NASM'
) + (
  ($env:PATH -split ';' | Where-Object {
    $_ -and $_ -ne 'C:\Program Files\LLVM\bin' -and `
    $_ -ne 'C:\Program Files\CMake\bin' -and `
    $_ -ne 'C:\Strawberry\c\bin'
  })
) -join ';'

$env:MSYSTEM = 'CLANG64'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'inherit'

$msysBash = 'C:\msys64\usr\bin\bash.exe'
if (-not (Test-Path $msysBash)) { throw "MSYS bash not found: $msysBash" }

Write-Host "=== Running FFmpeg MSVC build ==="
& $msysBash -lc './scripts/build-win-msvc.sh'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$libDir = Join-Path $dist 'prefix\lib'
if (-not (Test-Path $libDir)) {
  throw "Build output missing: $libDir"
}

Write-Host "=== Build output ==="
Get-ChildItem $libDir -Filter '*.lib' | ForEach-Object { $_.Name }
Get-ChildItem (Join-Path $dist 'bin') -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
