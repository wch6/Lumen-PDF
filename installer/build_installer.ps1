[CmdletBinding()]
param(
  [string]$BuildName = '',
  [string]$OutputDir = '',
  [string]$InnoSetupCompiler = 'D:\Inno_Setup_6\ISCC.exe',
  [switch]$SkipFlutterBuild,
  [switch]$NoDesktopShortcut
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$installerRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$workDir = Join-Path $repoRoot 'build\installer'
$distDir = if ($OutputDir.Trim()) {
  if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    [System.IO.Path]::GetFullPath($OutputDir)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDir))
  }
} else {
  Join-Path $workDir 'dist'
}

function Get-PubspecBuildName {
  $pubspec = Join-Path $repoRoot 'pubspec.yaml'
  $versionLine = Get-Content -LiteralPath $pubspec |
    Where-Object { $_ -match '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' } |
    Select-Object -First 1
  if (-not $versionLine) {
    return '1.0.0'
  }
  return [regex]::Match($versionLine, '([0-9]+\.[0-9]+\.[0-9]+)').Groups[1].Value
}

function Resolve-InnoSetupCompiler {
  param([string]$PreferredPath)

  $candidates = @()
  if ($PreferredPath.Trim()) {
    $candidates += $PreferredPath
  }

  $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($command) {
    $candidates += $command.Source
  }

  $registryRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  foreach ($root in $registryRoots) {
    $items = Get-ItemProperty $root -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -like '*Inno Setup*' -and $_.InstallLocation }
    foreach ($item in $items) {
      $candidates += (Join-Path $item.InstallLocation 'ISCC.exe')
    }
  }

  $candidates += @(
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  )

  foreach ($candidate in $candidates | Where-Object { $_ } | Select-Object -Unique) {
    if (Test-Path -LiteralPath $candidate) {
      return [System.IO.Path]::GetFullPath($candidate)
    }
  }

  throw 'ISCC.exe was not found. Pass -InnoSetupCompiler with the full path to ISCC.exe.'
}

Set-Location $repoRoot

if (-not $BuildName.Trim()) {
  $BuildName = Get-PubspecBuildName
}

if (-not ($BuildName -match '^\d+\.\d+\.\d+(\.\d+)?$')) {
  throw "Inno Setup requires a numeric version such as 1.0.0 or 1.0.0.1. Got: $BuildName"
}

if (-not $SkipFlutterBuild) {
  Write-Host "Building Flutter Windows release..."
  & flutter build windows --release --build-name $BuildName
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows failed with exit code $LASTEXITCODE"
  }
}

$appExe = Join-Path $releaseDir 'lumen.exe'
if (-not (Test-Path -LiteralPath $appExe)) {
  throw "Release executable not found: $appExe"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$compiler = Resolve-InnoSetupCompiler -PreferredPath $InnoSetupCompiler
$issPath = Join-Path $installerRoot 'lumen_pdf.iss'
$outputBaseFilename = "LumenPDF-Setup-$BuildName"
$setupExe = Join-Path $distDir "$outputBaseFilename.exe"

if (Test-Path -LiteralPath $setupExe) {
  Remove-Item -LiteralPath $setupExe -Force
}

$defines = @(
  "/DAppVersion=""$BuildName""",
  "/DRepoRoot=""$repoRoot""",
  "/DSourceDir=""$releaseDir""",
  "/DOutputDir=""$distDir""",
  "/DOutputBaseFilename=""$outputBaseFilename"""
)
if ($NoDesktopShortcut) {
  $defines += '/DNoDesktopShortcut'
}

Write-Host "Creating installer with Inno Setup..."
Write-Host "  Compiler: $compiler"
& $compiler /Qp @defines $issPath
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $setupExe)) {
  throw "Installer was not created: $setupExe"
}

$size = (Get-Item -LiteralPath $setupExe).Length
Write-Host "Installer created:"
Write-Host "  $setupExe"
Write-Host ("  {0:N1} MB" -f ($size / 1MB))
