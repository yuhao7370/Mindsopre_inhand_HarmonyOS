[CmdletBinding()]
param(
  [switch]$VerifyOnly,
  [ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a',
  [string]$DevEcoSdkRoot = '',
  [string]$CacheRoot = '',
  [string]$SourceArchive = '',
  [ValidateRange(1, 8)][int]$Jobs = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Jobs -ne 1) { throw 'The canonical XZ builder requires Jobs=1 for reproducible output.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$builder = Join-Path $repositoryRoot 'Mindspore_inhand_HarmonyOS\scripts\build-translation-xz-ohos.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw "Missing canonical XZ builder: $builder" }

if ($SourceArchive -and -not $VerifyOnly) {
  if (-not $CacheRoot) { $CacheRoot = Join-Path $env:LOCALAPPDATA 'MindsporeInhand\xz-ohos-5.8.3' }
  $CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
  [IO.Directory]::CreateDirectory($CacheRoot) | Out-Null
  $expectedHash = 'FFF1FFCF2B0DA84D308A14DE513A1AA23D4E9AA3464D17E64B9714BFDD0BBFB6'
  if ((Get-FileHash -LiteralPath $SourceArchive -Algorithm SHA256).Hash -cne $expectedHash) {
    throw 'XZ source SHA-256 mismatch.'
  }
  Copy-Item -LiteralPath $SourceArchive -Destination (Join-Path $CacheRoot 'xz-5.8.3.tar.xz') -Force
}

$arguments = @{ Abi = $Abi; VerifyOnly = $VerifyOnly }
if ($DevEcoSdkRoot) { $arguments.DevEcoSdkRoot = $DevEcoSdkRoot }
if ($CacheRoot) { $arguments.CacheRoot = $CacheRoot }
& $builder @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
