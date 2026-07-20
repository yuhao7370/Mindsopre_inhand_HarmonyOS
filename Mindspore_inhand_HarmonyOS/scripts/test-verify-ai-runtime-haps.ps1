$ErrorActionPreference = 'Stop'

$guard = Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "verify-ai-runtime-haps-$([guid]::NewGuid())"

function New-HapFixture([string]$Path, [hashtable]$Files) {
  $staging = Join-Path $tempRoot ([guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $staging | Out-Null
  foreach ($entry in $Files.Keys) {
    $file = Join-Path $staging ($entry.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
    Set-Content -LiteralPath $file -Value $Files[$entry] -NoNewline -Encoding utf8
  }
  $zip = "$Path.zip"
  Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip
  Move-Item -LiteralPath $zip -Destination $Path
}

function Add-DuplicateHapEntry([string]$Path, [string]$Entry, [string]$Content) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $fileStream = [System.IO.File]::Open(
    $Path,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
  )
  $archive = $null
  try {
    $archive = New-Object System.IO.Compression.ZipArchive(
      $fileStream,
      [System.IO.Compression.ZipArchiveMode]::Update,
      $false
    )
    $duplicate = $archive.CreateEntry($Entry.Replace('/', '\'))
    $entryStream = $duplicate.Open()
    try {
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
      $entryStream.Write($bytes, 0, $bytes.Length)
    } finally {
      $entryStream.Dispose()
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $fileStream.Dispose()
  }
}

function New-FileMap([string[]]$Entries) {
  $files = @{}
  foreach ($entry in $Entries) { $files[$entry] = 'fixture' }
  $files['module.json'] = '{}'
  return $files
}

function Write-ExpectedFiles([string]$Root, [hashtable]$Files, [string]$Prefix) {
  foreach ($entry in @($Files.Keys | Where-Object { $_.StartsWith($Prefix) })) {
    $relativePath = $entry.Substring($Prefix.Length)
    $file = Join-Path $Root ($relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
    Set-Content -LiteralPath $file -Value $Files[$entry] -NoNewline -Encoding utf8
  }
}

function Assert-GuardRejects(
  [string]$Label,
  [string]$MainHapPath,
  [string]$OhosTestHapPath,
  [string]$ExpectedMessage = ''
) {
  $rejected = $false
  $message = ''
  try {
    & $guard -MainHapPath $MainHapPath -OhosTestHapPath $OhosTestHapPath `
      -ExpectedRawfileRoot $expectedRawfileRoot -ExpectedNativeLibRoot $expectedNativeRoot *> $null
  } catch {
    $rejected = $true
    $message = $_.Exception.Message
  }
  if (-not $rejected) { throw "Guard unexpectedly accepted: $Label" }
  if ($ExpectedMessage -and -not $message.Contains($ExpectedMessage)) {
    throw "Guard rejected '$Label' for the wrong reason: $message"
  }
  Write-Host "Rejected invalid fixture: $Label"
}

function Assert-GuardAcceptsInFreshProcess([string]$MainHapPath, [string]$OhosTestHapPath) {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $guard `
      -MainHapPath $MainHapPath -OhosTestHapPath $OhosTestHapPath `
      -ExpectedRawfileRoot $expectedRawfileRoot -ExpectedNativeLibRoot $expectedNativeRoot 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) {
    throw "Fresh powershell.exe rejected valid fixture:`n$($output | Out-String)"
  }
  Write-Host 'Accepted valid fixture in fresh powershell.exe.'
}

$mainEntries = @(
  'module.json',
  'resources/rawfile/model/mobilenetv2.ms',
  'resources/rawfile/model/resnet18-place365.ms',
  'resources/rawfile/model/ssd.ms',
  'resources/rawfile/model/style_predict_quant.ms',
  'resources/rawfile/model/style_transfer_quant.ms',
  'resources/rawfile/model/selfie_segmentation.mnn',
  'resources/rawfile/model/selfie_segmentation.NOTICE.md',
  'resources/rawfile/model/LICENSE-Apache-2.0.txt',
  'resources/rawfile/model/NOTICE.md',
  'resources/rawfile/models/gesture/GestureDetector.ms',
  'resources/rawfile/models/gesture/manifest.json',
  'resources/rawfile/models/gesture/NOTICE.md',
  'resources/rawfile/models/translation/translation-models.tar.xz',
  'resources/rawfile/models/translation/tokenizer.model',
  'resources/rawfile/models/translation/tokenizer_runtime.json',
  'resources/rawfile/models/translation/vocab.json',
  'resources/rawfile/models/translation/manifest.json',
  'resources/rawfile/models/translation/SHA256SUMS',
  'resources/rawfile/models/translation/LICENSES.md',
  'libs/arm64-v8a/libgesture_mnn.so',
  'libs/arm64-v8a/libMNN.so',
  'libs/arm64-v8a/libtranslation_archive.so',
  'libs/arm64-v8a/libsegmentation_mnn.so'
)
$mainModule = @{
  app = @{ bundleName = 'com.yuhaofeng.mih' }
  module = @{ name = 'entry'; mainElement = 'EntryAbility'; type = 'entry' }
} | ConvertTo-Json -Depth 8 -Compress

$testModule = @{
  app = @{ bundleName = 'com.yuhaofeng.mih' }
  module = @{ name = 'entry_test'; mainElement = 'TestAbility'; type = 'feature' }
} | ConvertTo-Json -Depth 8 -Compress
$testPack = @{
  summary = @{
    app = @{ bundleName = 'com.yuhaofeng.mih' }
    modules = @(
      @{ distro = @{ moduleName = 'entry_test'; moduleType = 'feature' } },
      @{ distro = @{ moduleName = 'entry'; moduleType = 'entry' } }
    )
  }
} | ConvertTo-Json -Depth 8 -Compress
$testEntries = @(
  'module.json',
  'pack.info',
  'ets/modules.abc',
  'resources/rawfile/fixtures/gesture/open_palm.png'
)

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  $mainHap = Join-Path $tempRoot 'main.hap'
  $testHap = Join-Path $tempRoot 'test.hap'
  $mainFiles = New-FileMap $mainEntries
  $mainFiles['module.json'] = $mainModule
  $testFiles = New-FileMap $testEntries
  $testFiles['module.json'] = $testModule
  $testFiles['pack.info'] = $testPack
  $expectedRawfileRoot = Join-Path $tempRoot 'expected-rawfile'
  $expectedNativeRoot = Join-Path $tempRoot 'expected-native'
  Write-ExpectedFiles $expectedRawfileRoot $mainFiles 'resources/rawfile/'
  Write-ExpectedFiles $expectedNativeRoot $mainFiles 'libs/arm64-v8a/'
  New-HapFixture $mainHap $mainFiles
  New-HapFixture $testHap $testFiles
  & $guard -MainHapPath $mainHap -OhosTestHapPath $testHap `
    -ExpectedRawfileRoot $expectedRawfileRoot -ExpectedNativeLibRoot $expectedNativeRoot
  Assert-GuardAcceptsInFreshProcess $mainHap $testHap

  $tamperedModelHap = Join-Path $tempRoot 'tampered-model.hap'
  $tamperedModelFiles = New-FileMap $mainEntries
  $tamperedModelFiles['module.json'] = $mainModule
  $tamperedModelEntry = 'resources/rawfile/models/gesture/GestureDetector.ms'
  $tamperedModelFiles[$tamperedModelEntry] = 'fixturf'
  New-HapFixture $tamperedModelHap $tamperedModelFiles
  $expectedModelPath = Join-Path $expectedRawfileRoot 'models/gesture/GestureDetector.ms'
  Assert-GuardRejects 'tampered model content' $tamperedModelHap $testHap `
    "payload differs from expected file: $tamperedModelEntry; expected source path: $expectedModelPath"

  $tamperedAppModelHap = Join-Path $tempRoot 'tampered-app-model.hap'
  $tamperedAppModelFiles = New-FileMap $mainEntries
  $tamperedAppModelFiles['module.json'] = $mainModule
  $tamperedAppModelEntry = 'resources/rawfile/model/ssd.ms'
  $tamperedAppModelFiles[$tamperedAppModelEntry] = 'fixturf'
  New-HapFixture $tamperedAppModelHap $tamperedAppModelFiles
  $expectedAppModelPath = Join-Path $expectedRawfileRoot 'model/ssd.ms'
  Assert-GuardRejects 'tampered app model content' $tamperedAppModelHap $testHap `
    "payload differs from expected file: $tamperedAppModelEntry; expected source path: $expectedAppModelPath"

  $duplicateModelHap = Join-Path $tempRoot 'duplicate-model.hap'
  Copy-Item -LiteralPath $mainHap -Destination $duplicateModelHap
  Add-DuplicateHapEntry $duplicateModelHap $tamperedModelEntry 'fixturf'
  Assert-GuardRejects 'duplicate model entry' $duplicateModelHap $testHap `
    "payload entry must appear exactly once: $tamperedModelEntry; found 2"

  $tamperedLibraryHap = Join-Path $tempRoot 'tampered-library.hap'
  $tamperedLibraryFiles = New-FileMap $mainEntries
  $tamperedLibraryFiles['module.json'] = $mainModule
  $tamperedLibraryEntry = 'libs/arm64-v8a/libgesture_mnn.so'
  $tamperedLibraryFiles[$tamperedLibraryEntry] = 'fixturf'
  New-HapFixture $tamperedLibraryHap $tamperedLibraryFiles
  $expectedLibraryPath = Join-Path $expectedNativeRoot 'libgesture_mnn.so'
  Assert-GuardRejects 'tampered native library content' $tamperedLibraryHap $testHap `
    "payload differs from expected file: $tamperedLibraryEntry; expected source path: $expectedLibraryPath"

  $wrongMainBundleHap = Join-Path $tempRoot 'wrong-main-bundle.hap'
  $wrongMainBundleFiles = New-FileMap $mainEntries
  $wrongMainBundleFiles['module.json'] = $mainModule.Replace('com.yuhaofeng.mih', 'com.example.other')
  New-HapFixture $wrongMainBundleHap $wrongMainBundleFiles
  Assert-GuardRejects 'wrong main bundle name' $wrongMainBundleHap $testHap 'bundle names must match'

  $wrongMainModuleHap = Join-Path $tempRoot 'wrong-main-module.hap'
  $wrongMainModuleFiles = New-FileMap $mainEntries
  $wrongMainModuleFiles['module.json'] = $mainModule.Replace('"entry"', '"other"')
  New-HapFixture $wrongMainModuleHap $wrongMainModuleFiles
  Assert-GuardRejects 'wrong main module name' $wrongMainModuleHap $testHap 'Main HAP module name must be entry'

  $missingMainHap = Join-Path $tempRoot 'missing-main-entry.hap'
  New-HapFixture $missingMainHap (New-FileMap @($mainEntries | Select-Object -SkipLast 1))
  Assert-GuardRejects 'missing main entry' $missingMainHap $testHap 'Main HAP is missing:'

  $wrongModuleHap = Join-Path $tempRoot 'wrong-test-module.hap'
  $wrongModuleFiles = New-FileMap $testEntries
  $wrongModuleFiles['module.json'] = $testModule.Replace('entry_test', 'other_test')
  $wrongModuleFiles['pack.info'] = $testPack
  New-HapFixture $wrongModuleHap $wrongModuleFiles
  Assert-GuardRejects 'wrong test module name' $mainHap $wrongModuleHap 'ohosTest HAP module name must be entry_test'

  $missingEntryHap = Join-Path $tempRoot 'missing-paired-entry.hap'
  $missingEntryPack = @{
    summary = @{
      app = @{ bundleName = 'com.yuhaofeng.mih' }
      modules = @(@{ distro = @{ moduleName = 'entry_test'; moduleType = 'feature' } })
    }
  } | ConvertTo-Json -Depth 8 -Compress
  $missingEntryFiles = New-FileMap $testEntries
  $missingEntryFiles['module.json'] = $testModule
  $missingEntryFiles['pack.info'] = $missingEntryPack
  New-HapFixture $missingEntryHap $missingEntryFiles
  Assert-GuardRejects 'missing paired entry module' $mainHap $missingEntryHap 'must contain exactly one paired entry module'

  $copiedModelHap = Join-Path $tempRoot 'copied-model.hap'
  $copiedModelFiles = New-FileMap $testEntries
  $copiedModelFiles['module.json'] = $testModule
  $copiedModelFiles['pack.info'] = $testPack
  $copiedModelFiles['resources/rawfile/models/gesture/GestureDetector.ms'] = 'fixture'
  New-HapFixture $copiedModelHap $copiedModelFiles
  Assert-GuardRejects 'copied model in test HAP' $mainHap $copiedModelHap 'ohosTest HAP contains copied models'

  $copiedAppModelHap = Join-Path $tempRoot 'copied-app-model.hap'
  $copiedAppModelFiles = New-FileMap $testEntries
  $copiedAppModelFiles['module.json'] = $testModule
  $copiedAppModelFiles['pack.info'] = $testPack
  $copiedAppModelFiles['resources/rawfile/model/ssd.ms'] = 'fixture'
  New-HapFixture $copiedAppModelHap $copiedAppModelFiles
  Assert-GuardRejects 'copied app model in test HAP' $mainHap $copiedAppModelHap 'ohosTest HAP contains copied models'

  Write-Host 'HAP guard contract tests passed.'
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
