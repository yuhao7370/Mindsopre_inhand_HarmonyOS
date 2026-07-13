[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$SourceArchive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$buildScript = Join-Path $PSScriptRoot 'build_xz_ohos.ps1'
$manifestPath = Join-Path $repositoryRoot 'Mindspore_inhand_HarmonyOS\entry\src\main\cpp\translation_xz\XZ_BUILD_MANIFEST.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('mindspore-xz-cache-negative-' + [guid]::NewGuid().ToString('N'))
$legacySource = Join-Path $testRoot 'source'
$tampered = 'message(FATAL_ERROR "TAMPERED CACHED SOURCE MUST NOT BE USED")'

function Invoke-Build([string[]]$Arguments) {
  $previous = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

try {
  [IO.Directory]::CreateDirectory($legacySource) | Out-Null
  [IO.File]::WriteAllText((Join-Path $legacySource 'CMakeLists.txt'), $tampered, [Text.UTF8Encoding]::new($false))

  $build = Invoke-Build @('-CacheRoot', $testRoot, '-SourceArchive', [IO.Path]::GetFullPath($SourceArchive), '-Jobs', '1')
  if ($build.ExitCode -ne 0) { throw "Fresh-source build failed ($($build.ExitCode)):`n$($build.Output)" }
  if ([IO.File]::ReadAllText((Join-Path $legacySource 'CMakeLists.txt')) -cne $tampered) {
    throw 'The build modified or trusted the tampered legacy source cache.'
  }
  if (@(Get-ChildItem -LiteralPath $testRoot -Directory -Filter 'run.*').Count -ne 0) {
    throw 'Fresh XZ build work directory was not cleaned.'
  }

  $verify = Invoke-Build @('-VerifyOnly')
  if ($verify.ExitCode -ne 0) { throw "VerifyOnly rejected the fresh import:`n$($verify.Output)" }
  $builtManifest = [IO.File]::ReadAllText($manifestPath)
  try {
    $manifest = $builtManifest | ConvertFrom-Json
    $manifest.upstream.sourceSha256 = '0' * 64
    [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
    $tamperedVerify = Invoke-Build @('-VerifyOnly')
    if ($tamperedVerify.ExitCode -eq 0) { throw 'VerifyOnly accepted tampered source provenance.' }
  } finally {
    [IO.File]::WriteAllText($manifestPath, $builtManifest, [Text.UTF8Encoding]::new($false))
  }
  Write-Output 'Tampered cached XZ source was ignored; fresh verified extraction passed.'
} finally {
  $expectedPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  $resolved = [IO.Path]::GetFullPath($testRoot)
  if (-not $resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to clean a test path outside the system temporary directory.'
  }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
