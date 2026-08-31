$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Set-Location $env:GITHUB_WORKSPACE

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw 'Visual Studio not found' }

Import-Module "$vsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=amd64 -host_arch=amd64'

$clangCl = (Get-Command clang-cl -ErrorAction Stop).Source.Replace('\', '/')
if (-not (Test-Path $clangCl)) { throw "clang-cl not found: $clangCl" }

$envFile = Join-Path $env:GITHUB_WORKSPACE 'build\msvc-env.sh'
New-Item -Force -ItemType Directory (Split-Path $envFile) | Out-Null

$names = @(
  'PATH', 'INCLUDE', 'LIB', 'LIBPATH',
  'WindowsSdkDir', 'WindowsSDKLibVersion',
  'VCToolsInstallDir', 'VSINSTALLDIR',
  'UniversalCRTSdkDir', 'VSCMD_ARG_TGT_ARCH'
)

$lines = [System.Collections.Generic.List[string]]::new()
foreach ($name in $names) {
  $val = [Environment]::GetEnvironmentVariable($name, 'Process')
  if ([string]::IsNullOrEmpty($val)) { continue }
  $escaped = $val.Replace("'", "'\''")
  $lines.Add("export ${name}='$escaped'")
}
$lines.Add("export CLANG_CL='$($clangCl.Replace("'", "'\''"))'")

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($envFile, $lines, $utf8NoBom)

Write-Host "Exported MSVC environment to $envFile"
Write-Host "CLANG_CL=$clangCl"
