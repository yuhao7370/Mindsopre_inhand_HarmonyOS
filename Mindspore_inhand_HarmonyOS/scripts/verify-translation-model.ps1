[CmdletBinding()]
param(
  [string]$StageRoot = '',
  [string]$PackageManifestPath = '',
  [string]$NativeDecompressorPath = '',
  [string]$ReleaseEvidencePath = '',
  [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '..'))
if (-not $StageRoot) {
  $StageRoot = Join-Path $projectRoot 'entry\src\main\resources\rawfile\models\translation'
}
$StageRoot = [IO.Path]::GetFullPath($StageRoot)
foreach ($abi in @('arm64-v8a', 'x86_64')) {
  $library = Join-Path $projectRoot "entry\libs\$abi\libtranslation_archive.so"
  if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
    throw "Missing $abi translation archive library: $library"
  }
}

Push-Location $repositoryRoot
try {
  & $Python -m tools.translation.verify_open_source_translation_package --root $StageRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Translation schema-v2 package verifier failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
