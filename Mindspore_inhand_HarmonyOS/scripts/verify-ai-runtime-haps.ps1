param(
  [Parameter(Mandatory = $true)][string]$MainHapPath,
  [string]$OhosTestHapPath = '',
  [string]$ExpectedRawfileRoot = '',
  [string]$ExpectedNativeLibRoot = '',
  [string]$ExpectedNativeLibRootX86 = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildProfile = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\build-profile.json5') -Raw

$abiSectionMatch = [regex]::Match($buildProfile, '"abiFilters"\s*:\s*\[(?<abis>.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $abiSectionMatch.Success) {
  throw 'Unable to read abiFilters from build-profile.json5'
}
$targetAbis = [regex]::Matches($abiSectionMatch.Groups['abis'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if (-not $targetAbis) {
  $targetAbis = @('arm64-v8a')
}

if (-not $ExpectedRawfileRoot) {
  $ExpectedRawfileRoot = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile'
}
if (-not $ExpectedNativeLibRoot) {
  $ExpectedNativeLibRoot = Join-Path $PSScriptRoot '..\entry\build\default\intermediates\stripped_native_libs\default\arm64-v8a'
  $ExpectedNativeLibRootX86 = Join-Path $PSScriptRoot '..\entry\build\default\intermediates\stripped_native_libs\default\x86_64'
}
if (-not $ExpectedNativeLibRootX86) {
  $ExpectedNativeLibRootX86 = $ExpectedNativeLibRoot
}

function Get-HapEntries([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "HAP does not exist: $Path"
  }
  $entries = @(& tar -tf $Path)
  if ($LASTEXITCODE -ne 0) { throw "Unable to list HAP: $Path" }
  return $entries
}

function Read-HapJson([string]$Path, [string]$Entry) {
  $text = (& tar -xOf $Path $Entry | Out-String)
  if ($LASTEXITCODE -ne 0) { throw "Unable to read $Entry from $Path" }
  return $text | ConvertFrom-Json
}

function Assert-ExactEntries([string[]]$Entries, [string[]]$Required, [string]$Label) {
  $missing = @($Required | Where-Object { $Entries -notcontains $_ })
  if ($missing.Count -ne 0) { throw "$Label is missing: $($missing -join ', ')" }
}

function Assert-HapPayloadHashes([string]$Path, [object[]]$Payloads) {
  $fileStream = [System.IO.File]::OpenRead($Path)
  $archive = $null
  try {
    $archive = New-Object System.IO.Compression.ZipArchive(
      $fileStream,
      [System.IO.Compression.ZipArchiveMode]::Read,
      $false
    )
    foreach ($payload in $Payloads) {
      if (-not (Test-Path -LiteralPath $payload.ExpectedPath -PathType Leaf)) {
        throw "Expected HAP payload does not exist: $($payload.ExpectedPath)"
      }
      $matches = @($archive.Entries | Where-Object {
        $_.FullName.Replace('\', '/') -ceq $payload.Entry
      })
      if ($matches.Count -ne 1) {
        throw "Main HAP payload entry must appear exactly once: $($payload.Entry); found $($matches.Count)"
      }
      $entry = $matches[0]

      $entryStream = $entry.Open()
      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      try {
        $actualHash = [System.BitConverter]::ToString($sha256.ComputeHash($entryStream)).Replace('-', '')
      } finally {
        $sha256.Dispose()
        $entryStream.Dispose()
      }
      $expectedHash = (Get-FileHash -LiteralPath $payload.ExpectedPath -Algorithm SHA256).Hash
      if ($actualHash -cne $expectedHash) {
        throw "Main HAP payload differs from expected file: $($payload.Entry); expected source path: $($payload.ExpectedPath)"
      }
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $fileStream.Dispose()
  }
}

$resourceEntries = @(
  'resources/rawfile/model/mobilenetv2.ms',
  'resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms',
  'resources/rawfile/model/resnet18-place365.ms',
  'resources/rawfile/model/nanodet_plus_m_320.mnn',
  'resources/rawfile/model/style_predict_fp16.mnn',
  'resources/rawfile/model/style_transform_fp16.mnn',
  'resources/rawfile/model/custom_channel_mean.ms',
  'resources/rawfile/model/custom_channel_mean_inverted.ms',
  'resources/rawfile/model/custom_channel_mean_non_finite.ms',
  'resources/rawfile/model/selfie_segmentation.mnn',
  'resources/rawfile/model/selfie_segmentation.NOTICE.md',
  'resources/rawfile/model/LICENSE-Apache-2.0.txt',
  'resources/rawfile/model/NOTICE.md',
  'resources/rawfile/models/gesture/GestureDetector.ms',
  'resources/rawfile/models/gesture/manifest.json',
  'resources/rawfile/models/gesture/NOTICE.md',
  'resources/rawfile/models/ocr/ppocrv3_det.mnn',
  'resources/rawfile/models/ocr/ppocrv3_rec.mnn',
  'resources/rawfile/models/ocr/ppocr_keys_v1.txt',
  'resources/rawfile/models/ocr/NOTICE.md',
  'resources/rawfile/models/translation/translation-models.tar.xz',
  'resources/rawfile/models/translation/tokenizer.model',
  'resources/rawfile/models/translation/tokenizer_runtime.json',
  'resources/rawfile/models/translation/vocab.json',
  'resources/rawfile/models/translation/manifest.json',
  'resources/rawfile/models/translation/SHA256SUMS',
  'resources/rawfile/models/translation/LICENSES.md'
)
$nativeEntries = @(
  foreach ($abi in $targetAbis) {
    "libs/$abi/libgesture_mnn.so"
    "libs/$abi/libMNN.so"
    "libs/$abi/libtranslation_archive.so"
    "libs/$abi/libsegmentation_mnn.so"
    "libs/$abi/libobject_detection_mnn.so"
    "libs/$abi/libocr_mnn.so"
    "libs/$abi/libstyle_transfer_mnn.so"
  }
)
$mainEntries = @('module.json') + $resourceEntries + $nativeEntries
$mainHapEntries = @(Get-HapEntries $MainHapPath)
Assert-ExactEntries $mainHapEntries $mainEntries 'Main HAP'
$mainModule = Read-HapJson $MainHapPath 'module.json'
if ($mainModule.module.name -ne 'entry') { throw 'Main HAP module name must be entry' }
$payloads = @(
  foreach ($entry in $resourceEntries) {
    [pscustomobject]@{
      Entry = $entry
      ExpectedPath = Join-Path $ExpectedRawfileRoot $entry.Substring('resources/rawfile/'.Length)
    }
  }
  foreach ($entry in $nativeEntries) {
    $split = $entry -split '/'
    $abi = $split[1]
    $filename = $split[2]
    $nativeRoot = if ($abi -eq 'x86_64') { $ExpectedNativeLibRootX86 } else { $ExpectedNativeLibRoot }
    [pscustomobject]@{
      Entry = $entry
      ExpectedPath = Join-Path $nativeRoot $filename
    }
  }
)
Assert-HapPayloadHashes $MainHapPath $payloads

if ($OhosTestHapPath) {
  $testRequired = @(
    'module.json',
    'pack.info',
    'ets/modules.abc',
    'resources/rawfile/fixtures/gesture/open_palm.png',
    'resources/rawfile/fixtures/posenet/labels.json'
  )
  $testHapEntries = @(Get-HapEntries $OhosTestHapPath)
  Assert-ExactEntries $testHapEntries $testRequired 'ohosTest HAP'

  $copiedModels = @($testHapEntries | Where-Object {
    $_.StartsWith('resources/rawfile/model/') -or $_.StartsWith('resources/rawfile/models/')
  })
  if ($copiedModels.Count -ne 0) {
    throw "ohosTest HAP contains copied models: $($copiedModels -join ', ')"
  }
  $aiLibraries = @('libgesture_mnn.so', 'libMNN.so', 'libtranslation_archive.so', 'libsegmentation_mnn.so', 'libobject_detection_mnn.so', 'libocr_mnn.so', 'libstyle_transfer_mnn.so')
  $copiedLibraries = @($testHapEntries | Where-Object { $aiLibraries -contains ($_ -split '/')[-1] })
  if ($copiedLibraries.Count -ne 0) {
    throw "ohosTest HAP contains copied AI libraries: $($copiedLibraries -join ', ')"
  }

  $module = Read-HapJson $OhosTestHapPath 'module.json'
  $pack = Read-HapJson $OhosTestHapPath 'pack.info'
  if ($mainModule.app.bundleName -ne $module.app.bundleName -or
      $module.app.bundleName -ne $pack.summary.app.bundleName) {
    throw 'Main HAP, ohosTest HAP, and pack.info bundle names must match'
  }
  if ($module.module.name -ne 'entry_test') { throw 'ohosTest HAP module name must be entry_test' }
  if ($module.module.mainElement -ne 'TestAbility') { throw 'ohosTest HAP main element must be TestAbility' }
  if (@($pack.summary.modules | Where-Object { $_.distro.moduleName -eq 'entry_test' }).Count -ne 1) {
    throw 'ohosTest HAP pack.info must contain exactly one entry_test module'
  }
  if (@($pack.summary.modules | Where-Object { $_.distro.moduleName -eq 'entry' }).Count -ne 1) {
    throw 'ohosTest HAP pack.info must contain exactly one paired entry module'
  }
}

$verified = @("main=$MainHapPath")
if ($OhosTestHapPath) { $verified += "ohosTest=$OhosTestHapPath" }
Write-Host "Verified AI runtime HAP structure and payload bytes: $($verified -join '; ')"
