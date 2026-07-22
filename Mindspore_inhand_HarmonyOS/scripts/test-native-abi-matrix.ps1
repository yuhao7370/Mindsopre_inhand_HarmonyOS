[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profile = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\build-profile.json5') -Raw
$mainCMake = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\src\main\cpp\CMakeLists.txt') -Raw
$translationCMake = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\src\main\cpp\translation_xz\CMakeLists.txt') -Raw
$buildHap = Get-Content -LiteralPath (Join-Path $projectRoot 'scripts\build-hap.ps1') -Raw
$acceptance = Get-Content -LiteralPath (Join-Path $projectRoot 'scripts\build-ai-runtime-acceptance.ps1') -Raw
$abiSectionMatch = [regex]::Match($profile, '"abiFilters"\s*:\s*\[(?<abis>.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $abiSectionMatch.Success) { throw 'Unable to read abiFilters from build-profile.json5' }
$abis = [regex]::Matches($abiSectionMatch.Groups['abis'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

if (-not $abis) { throw 'abiFilters list in build-profile.json5 is empty.' }
$expectedAbis = @('arm64-v8a', 'x86_64')
if (($abis -join ',') -cne ($expectedAbis -join ',')) {
  throw "abiFilters must be arm64-v8a,x86_64; got $($abis -join ',')"
}

foreach ($abi in $expectedAbis) {
  if ($profile -cnotmatch ('"' + [regex]::Escape($abi) + '"')) {
    throw "entry/build-profile.json5 does not package ABI $abi"
  }
  $mnnManifestName = if ($abi -ceq 'arm64-v8a') { 'MNN_BUILD_MANIFEST.json' } else { "MNN_BUILD_MANIFEST.$abi.json" }
  $xzManifestName = if ($abi -ceq 'arm64-v8a') { 'XZ_BUILD_MANIFEST.json' } else { "XZ_BUILD_MANIFEST.$abi.json" }
  $mnnManifestPath = Join-Path $projectRoot "entry\src\main\cpp\$mnnManifestName"
  $xzManifestPath = Join-Path $projectRoot "entry\src\main\cpp\translation_xz\$xzManifestName"
  $mnnPath = Join-Path $projectRoot "entry\libs\$abi\libMNN.so"
  $lzmaPath = Join-Path $projectRoot "entry\src\main\cpp\translation_xz\third_party\xz\lib\$abi\liblzma.a"
  $wrapperPath = Join-Path $projectRoot "entry\libs\$abi\libtranslation_archive.so"
  foreach ($path in @($mnnManifestPath, $xzManifestPath, $mnnPath, $lzmaPath, $wrapperPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Missing native dependency for ${abi}: $path"
    }
  }
  $mnn = Get-Content -LiteralPath $mnnManifestPath -Raw | ConvertFrom-Json
  $xz = Get-Content -LiteralPath $xzManifestPath -Raw | ConvertFrom-Json
  if ($mnn.toolchain.abi -cne $abi -or $xz.toolchain.abi -cne $abi) { throw "Manifest ABI mismatch: $abi" }
  if ((Get-FileHash -LiteralPath $mnnPath -Algorithm SHA256).Hash -cne $mnn.artifact.sha256) { throw "MNN hash mismatch: $abi" }
  if ((Get-FileHash -LiteralPath $lzmaPath -Algorithm SHA256).Hash -cne $xz.artifacts.liblzma.sha256) { throw "liblzma hash mismatch: $abi" }
  if ((Get-FileHash -LiteralPath $wrapperPath -Algorithm SHA256).Hash -cne $xz.artifacts.napi.sha256) { throw "translation wrapper hash mismatch: $abi" }
}

if ($translationCMake -cnotmatch 'lib/\$\{OHOS_ARCH\}/liblzma\.a') {
  throw 'translation_xz/CMakeLists.txt must select liblzma by OHOS_ARCH.'
}
foreach ($builder in @('build-mnn-ohos.ps1', 'build-translation-xz-ohos.ps1')) {
  if ($buildHap -cnotmatch [regex]::Escape($builder)) { throw "build-hap.ps1 must verify $builder for every ABI." }
}
foreach ($library in @('libgesture_mnn.so', 'libsegmentation_mnn.so', 'libobject_detection_mnn.so', 'libocr_mnn.so', 'libstyle_transfer_mnn.so')) {
  if ($acceptance -cnotmatch [regex]::Escape($library)) { throw "Acceptance gate must verify stripped library: $library" }
}
if ($acceptance -cnotmatch 'Advanced Micro Devices X86-64' -or $acceptance -cnotmatch '\$ORIGIN') {
  throw 'Acceptance gate must validate per-ABI ELF machine and MNN wrapper runpath.'
}

Write-Output ('Native ABI matrix contract passed: ' + ($expectedAbis -join ', '))
