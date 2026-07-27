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
  if ($null -ne $script:canonicalTranslationFiles) {
    foreach ($entry in $script:canonicalTranslationFiles.Keys) {
      if ($files.ContainsKey($entry)) { $files[$entry] = $script:canonicalTranslationFiles[$entry] }
    }
  }
  if ($null -ne $script:canonicalAppConfiguration -and
    $files.ContainsKey('resources/base/profile/configuration.json')) {
    $files['resources/base/profile/configuration.json'] = $script:canonicalAppConfiguration
  }
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
      -ExpectedAppResourceRoot $expectedAppResourceRoot `
      -ExpectedResourceRoot $expectedResourceRoot `
      -ExpectedOhosTestResourceRoot $expectedOhosTestResourceRoot `
      -ExpectedRawfileRoot $expectedRawfileRoot -ExpectedNativeLibRoot $expectedNativeRoot `
      -ExpectedTranslationPackageLock $expectedTranslationPackageLock *> $null
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

$mainEntries = @(
  'module.json',
  'pack.info',
  'pkgContextInfo.json',
  'ets/modules.abc',
  'ets/sourceMaps.map',
  'resources.index',
  'resources/base/media/icon.png',
  'resources/base/profile/configuration.json',
  'resources/base/profile/main_pages.json',
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
  'resources/rawfile/models/translation/manifest.json',
  'resources/rawfile/models/translation/SHA256SUMS',
  'resources/rawfile/models/translation/LICENSES.md',
  'libs/arm64-v8a/libgesture_mnn.so',
  'libs/arm64-v8a/libMNN.so',
  'libs/arm64-v8a/libtranslation_archive.so',
  'libs/arm64-v8a/libsegmentation_mnn.so',
  'libs/arm64-v8a/libobject_detection_mnn.so',
  'libs/arm64-v8a/libocr_mnn.so',
  'libs/arm64-v8a/libstyle_transfer_mnn.so',
  'libs/arm64-v8a/libc++_shared.so',
  'libs/x86_64/libgesture_mnn.so',
  'libs/x86_64/libMNN.so',
  'libs/x86_64/libtranslation_archive.so',
  'libs/x86_64/libsegmentation_mnn.so',
  'libs/x86_64/libobject_detection_mnn.so',
  'libs/x86_64/libocr_mnn.so',
  'libs/x86_64/libstyle_transfer_mnn.so',
  'libs/x86_64/libc++_shared.so'
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
  'pkgContextInfo.json',
  'ets/modules.abc',
  'ets/sourceMaps.map',
  'resources.index',
  'resources/base/media/icon.png',
  'resources/base/profile/configuration.json',
  'resources/base/profile/main_pages.json',
  'resources/base/profile/test_pages.json',
  'resources/rawfile/mock/mock-config.json',
  'resources/rawfile/fixtures/gesture/open_palm.png',
  'resources/rawfile/fixtures/posenet/labels.json',
  'resources/rawfile/fixtures/segmentation/person.jpg',
  'resources/rawfile/fixtures/segmentation/person_mask.png'
)

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  $mainHap = Join-Path $tempRoot 'main.hap'
  $testHap = Join-Path $tempRoot 'test.hap'
  $script:canonicalAppConfiguration = Get-Content -LiteralPath `
    (Join-Path $PSScriptRoot '..\AppScope\resources\base\profile\configuration.json') -Raw
  $mainFiles = New-FileMap $mainEntries
  $mainFiles['module.json'] = $mainModule
  $testFiles = New-FileMap $testEntries
  $testFiles['module.json'] = $testModule
  $testFiles['pack.info'] = $testPack
  $expectedAppResourceRoot = Join-Path $tempRoot 'expected-app-resources'
  $expectedResourceRoot = Join-Path $tempRoot 'expected-resources'
  $expectedOhosTestResourceRoot = Join-Path $tempRoot 'expected-test-resources'
  $expectedRawfileRoot = Join-Path $expectedResourceRoot 'rawfile'
  $expectedNativeRoot = Join-Path $tempRoot 'expected-native'
  $appResourceFiles = @{
    'resources/base/profile/configuration.json' = $script:canonicalAppConfiguration
  }
  $entryResourceFiles = @{}
  foreach ($entry in $mainFiles.Keys) {
    if ($entry -ne 'resources/base/profile/configuration.json') {
      $entryResourceFiles[$entry] = $mainFiles[$entry]
    }
  }
  $testResourceFiles = @{}
  foreach ($entry in $testFiles.Keys) {
    if ($entry -ne 'resources/base/profile/configuration.json') {
      $testResourceFiles[$entry] = $testFiles[$entry]
    }
  }
  Write-ExpectedFiles $expectedAppResourceRoot $appResourceFiles 'resources/'
  Write-ExpectedFiles $expectedResourceRoot $entryResourceFiles 'resources/'
  Write-ExpectedFiles $expectedOhosTestResourceRoot $testResourceFiles 'resources/'
  Write-ExpectedFiles $expectedNativeRoot $mainFiles 'libs/arm64-v8a/'
  $translationEntry = 'resources/rawfile/models/translation/translation-models.tar.xz'
  $translationManifestEntry = 'resources/rawfile/models/translation/manifest.json'
  $translationArchivePath = Join-Path $expectedRawfileRoot 'models\translation\translation-models.tar.xz'
  $translationManifestPath = Join-Path $expectedRawfileRoot 'models\translation\manifest.json'
  $translationManifestTemplatePath = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\translation\manifest.json'
  $translationManifest = Get-Content -LiteralPath $translationManifestTemplatePath -Raw | ConvertFrom-Json
  $translationManifest.archive.size = (Get-Item -LiteralPath $translationArchivePath).Length
  $translationManifest.archive.sha256 = (Get-FileHash -LiteralPath $translationArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $translationManifestText = $translationManifest | ConvertTo-Json -Depth 32 -Compress
  $mainFiles[$translationManifestEntry] = $translationManifestText
  $script:canonicalTranslationFiles = @{}
  $script:canonicalTranslationFiles[$translationEntry] = $mainFiles[$translationEntry]
  $script:canonicalTranslationFiles[$translationManifestEntry] = $translationManifestText
  Set-Content -LiteralPath $translationManifestPath -Value $translationManifestText -NoNewline -Encoding utf8
  $expectedTranslationPackageLock = Join-Path $tempRoot 'translation-package-lock.json'
  $translationDescriptors = @(
    $translationManifest.directions.en.graphs.encoder,
    $translationManifest.directions.en.graphs.decoderFull,
    $translationManifest.directions.en.tokenizers.source,
    $translationManifest.directions.zh.graphs.encoder,
    $translationManifest.directions.zh.graphs.decoderFull,
    $translationManifest.directions.zh.tokenizers.source,
    $translationManifest.directions.zh.tokenizers.target
  )
  $translationMemberNames = @(
    'zh-en/encoder.ms', 'zh-en/decoder_full.ms', 'zh-en/tokenizer.ttok',
    'en-zh/encoder.ms', 'en-zh/decoder_full.ms', 'en-zh/source.ttok', 'en-zh/target.ttok'
  )
  $translationMembers = @()
  for ($memberIndex = 0; $memberIndex -lt 7; $memberIndex++) {
    $translationMembers += [ordered]@{
      name = $translationMemberNames[$memberIndex]
      size = $translationDescriptors[$memberIndex].size
      sha256 = $translationDescriptors[$memberIndex].sha256
    }
  }
  $translationLock = [ordered]@{
    schemaVersion = 2
    runtimeManifest = [ordered]@{
      file = 'manifest.json'
      size = (Get-Item -LiteralPath $translationManifestPath).Length
      sha256 = (Get-FileHash -LiteralPath $translationManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    archive = [ordered]@{
      file = 'translation-models.tar.xz'
      size = $translationManifest.archive.size
      sha256 = $translationManifest.archive.sha256
    }
    tar = [ordered]@{
      file = 'translation-models.tar'
      size = $translationManifest.archive.tarSize
      sha256 = $translationManifest.archive.tarSha256
    }
    members = $translationMembers
    tokenizers = [ordered]@{
      'zh-en/shared' = [ordered]@{
        file = $translationManifest.directions.en.tokenizers.source.file
        modelSha256 = $translationManifest.directions.en.tokenizers.source.modelSha256
        vocabularySha256 = $translationManifest.directions.en.tokenizers.source.vocabularySha256
        pieceCount = $translationManifest.directions.en.tokenizers.source.pieceCount
        decodeVocabularySize = $translationManifest.directions.en.tokenizers.source.decodeVocabularySize
        specialTokens = $translationManifest.directions.en.tokenizers.source.specialTokens
      }
      'en-zh/source' = [ordered]@{
        file = $translationManifest.directions.zh.tokenizers.source.file
        modelSha256 = $translationManifest.directions.zh.tokenizers.source.modelSha256
        vocabularySha256 = $translationManifest.directions.zh.tokenizers.source.vocabularySha256
        pieceCount = $translationManifest.directions.zh.tokenizers.source.pieceCount
        decodeVocabularySize = $translationManifest.directions.zh.tokenizers.source.decodeVocabularySize
        specialTokens = $translationManifest.directions.zh.tokenizers.source.specialTokens
      }
      'en-zh/target' = [ordered]@{
        file = $translationManifest.directions.zh.tokenizers.target.file
        modelSha256 = $translationManifest.directions.zh.tokenizers.target.modelSha256
        vocabularySha256 = $translationManifest.directions.zh.tokenizers.target.vocabularySha256
        pieceCount = $translationManifest.directions.zh.tokenizers.target.pieceCount
        decodeVocabularySize = $translationManifest.directions.zh.tokenizers.target.decodeVocabularySize
        specialTokens = $translationManifest.directions.zh.tokenizers.target.specialTokens
      }
    }
  }
  Set-Content -LiteralPath $expectedTranslationPackageLock `
    -Value ($translationLock | ConvertTo-Json -Depth 32) -NoNewline -Encoding utf8
  New-HapFixture $mainHap $mainFiles
  New-HapFixture $testHap $testFiles
  $verifiedOutput = & $guard -MainHapPath $mainHap -OhosTestHapPath $testHap `
    -ExpectedAppResourceRoot $expectedAppResourceRoot `
    -ExpectedResourceRoot $expectedResourceRoot `
    -ExpectedOhosTestResourceRoot $expectedOhosTestResourceRoot `
    -ExpectedRawfileRoot $expectedRawfileRoot -ExpectedNativeLibRoot $expectedNativeRoot `
    -ExpectedTranslationPackageLock $expectedTranslationPackageLock | Out-String
  if (-not $verifiedOutput.Contains('abis=arm64-v8a,x86_64')) {
    throw 'HAP verifier must report both configured target ABIs.'
  }

  $tamperedTranslationHap = Join-Path $tempRoot 'tampered-translation-package.hap'
  $tamperedTranslationFiles = @{}
  foreach ($entry in $mainFiles.Keys) { $tamperedTranslationFiles[$entry] = $mainFiles[$entry] }
  $tamperedTranslationFiles[$translationEntry] = 'tampered-archive'
  Set-Content -LiteralPath $translationArchivePath -Value 'tampered-archive' -NoNewline -Encoding utf8
  $tamperedTranslationManifest = $translationManifestText | ConvertFrom-Json
  $tamperedTranslationManifest.archive.size = (Get-Item -LiteralPath $translationArchivePath).Length
  $tamperedTranslationManifest.archive.sha256 = `
    (Get-FileHash -LiteralPath $translationArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $tamperedTranslationManifestText = $tamperedTranslationManifest | ConvertTo-Json -Depth 32 -Compress
  $tamperedTranslationFiles[$translationManifestEntry] = $tamperedTranslationManifestText
  Set-Content -LiteralPath $translationManifestPath `
    -Value $tamperedTranslationManifestText -NoNewline -Encoding utf8
  New-HapFixture $tamperedTranslationHap $tamperedTranslationFiles
  Assert-GuardRejects 'consistent manifest and archive translation package tamper' `
    $tamperedTranslationHap $testHap 'differs from external package lock'
  Set-Content -LiteralPath $translationArchivePath `
    -Value $mainFiles[$translationEntry] -NoNewline -Encoding utf8
  Set-Content -LiteralPath $translationManifestPath `
    -Value $translationManifestText -NoNewline -Encoding utf8

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
  $tamperedAppModelEntry = 'resources/rawfile/model/nanodet_plus_m_320.mnn'
  $tamperedAppModelFiles[$tamperedAppModelEntry] = 'fixturf'
  New-HapFixture $tamperedAppModelHap $tamperedAppModelFiles
  $expectedAppModelPath = Join-Path $expectedRawfileRoot 'model/nanodet_plus_m_320.mnn'
  Assert-GuardRejects 'tampered app model content' $tamperedAppModelHap $testHap `
    "payload differs from expected file: $tamperedAppModelEntry; expected source path: $expectedAppModelPath"

  $duplicateModelHap = Join-Path $tempRoot 'duplicate-model.hap'
  Copy-Item -LiteralPath $mainHap -Destination $duplicateModelHap
  Add-DuplicateHapEntry $duplicateModelHap $tamperedModelEntry 'fixturf'
  Assert-GuardRejects 'duplicate model entry' $duplicateModelHap $testHap `
    'Main HAP has duplicate entries: resources/rawfile/models/gesture/GestureDetector.ms'

  $tamperedLibraryHap = Join-Path $tempRoot 'tampered-library.hap'
  $tamperedLibraryFiles = New-FileMap $mainEntries
  $tamperedLibraryFiles['module.json'] = $mainModule
  $tamperedLibraryEntry = 'libs/arm64-v8a/libgesture_mnn.so'
  $tamperedLibraryFiles[$tamperedLibraryEntry] = 'fixturf'
  New-HapFixture $tamperedLibraryHap $tamperedLibraryFiles
  $expectedLibraryPath = Join-Path $expectedNativeRoot 'libgesture_mnn.so'
  Assert-GuardRejects 'tampered native library content' $tamperedLibraryHap $testHap `
    "payload differs from expected file: $tamperedLibraryEntry; expected source path: $expectedLibraryPath"

  $tamperedOcrHap = Join-Path $tempRoot 'tampered-ocr.hap'
  $tamperedOcrFiles = New-FileMap $mainEntries
  $tamperedOcrFiles['module.json'] = $mainModule
  $tamperedOcrEntry = 'resources/rawfile/models/ocr/ppocrv3_rec.mnn'
  $tamperedOcrFiles[$tamperedOcrEntry] = 'fixturf'
  New-HapFixture $tamperedOcrHap $tamperedOcrFiles
  $expectedOcrPath = Join-Path $expectedRawfileRoot 'models/ocr/ppocrv3_rec.mnn'
  Assert-GuardRejects 'tampered OCR payload' $tamperedOcrHap $testHap `
    "payload differs from expected file: $tamperedOcrEntry; expected source path: $expectedOcrPath"

  $missingOcrHap = Join-Path $tempRoot 'missing-ocr.hap'
  $missingOcrFiles = New-FileMap @($mainEntries | Where-Object { $_ -ne 'libs/arm64-v8a/libocr_mnn.so' })
  $missingOcrFiles['module.json'] = $mainModule
  New-HapFixture $missingOcrHap $missingOcrFiles
  Assert-GuardRejects 'missing OCR library payload' $missingOcrHap $testHap 'Main HAP is missing: libs/arm64-v8a/libocr_mnn.so'

  $missingObjectDetectionHap = Join-Path $tempRoot 'missing-object-detection.hap'
  $missingObjectDetectionFiles = New-FileMap @($mainEntries | Where-Object { $_ -ne 'libs/arm64-v8a/libobject_detection_mnn.so' })
  $missingObjectDetectionFiles['module.json'] = $mainModule
  New-HapFixture $missingObjectDetectionHap $missingObjectDetectionFiles
  Assert-GuardRejects 'missing object-detection library payload' $missingObjectDetectionHap $testHap `
    'Main HAP is missing: libs/arm64-v8a/libobject_detection_mnn.so'

  $missingStyleTransferHap = Join-Path $tempRoot 'missing-style-transfer.hap'
  $missingStyleTransferFiles = New-FileMap @($mainEntries | Where-Object { $_ -ne 'libs/arm64-v8a/libstyle_transfer_mnn.so' })
  $missingStyleTransferFiles['module.json'] = $mainModule
  New-HapFixture $missingStyleTransferHap $missingStyleTransferFiles
  Assert-GuardRejects 'missing style-transfer library payload' $missingStyleTransferHap $testHap `
    'Main HAP is missing: libs/arm64-v8a/libstyle_transfer_mnn.so'

  $missingX86Hap = Join-Path $tempRoot 'missing-x86-library.hap'
  $missingX86Files = New-FileMap @($mainEntries | Where-Object { $_ -ne 'libs/x86_64/libgesture_mnn.so' })
  $missingX86Files['module.json'] = $mainModule
  New-HapFixture $missingX86Hap $missingX86Files
  Assert-GuardRejects 'missing x86 library payload' $missingX86Hap $testHap `
    'Main HAP is missing: libs/x86_64/libgesture_mnn.so'

  $unexpectedAbiHap = Join-Path $tempRoot 'unexpected-abi-library.hap'
  $unexpectedAbiFiles = New-FileMap $mainEntries
  $unexpectedAbiFiles['module.json'] = $mainModule
  $unexpectedAbiFiles['libs/riscv64/libgesture_mnn.so'] = 'fixture'
  New-HapFixture $unexpectedAbiHap $unexpectedAbiFiles
  Assert-GuardRejects 'unexpected third ABI payload' $unexpectedAbiHap $testHap `
    'Main HAP has unexpected entries: libs/riscv64/libgesture_mnn.so'

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

  $missingSegmentationMaskHap = Join-Path $tempRoot 'missing-segmentation-mask.hap'
  $missingSegmentationMaskFiles = New-FileMap @($testEntries | Where-Object {
    $_ -ne 'resources/rawfile/fixtures/segmentation/person_mask.png'
  })
  $missingSegmentationMaskFiles['module.json'] = $testModule
  $missingSegmentationMaskFiles['pack.info'] = $testPack
  New-HapFixture $missingSegmentationMaskHap $missingSegmentationMaskFiles
  Assert-GuardRejects 'missing segmentation mask' $mainHap $missingSegmentationMaskHap `
    'ohosTest HAP is missing: resources/rawfile/fixtures/segmentation/person_mask.png'

  $leakedSegmentationFixtureHap = Join-Path $tempRoot 'leaked-segmentation-fixture.hap'
  $leakedSegmentationFixtureFiles = New-FileMap $mainEntries
  $leakedSegmentationFixtureFiles['module.json'] = $mainModule
  $leakedSegmentationFixtureFiles['resources/rawfile/fixtures/segmentation/person.jpg'] = 'fixture'
  New-HapFixture $leakedSegmentationFixtureHap $leakedSegmentationFixtureFiles
  Assert-GuardRejects 'segmentation fixture in main HAP' $leakedSegmentationFixtureHap $testHap `
    'Main HAP has unexpected entries: resources/rawfile/fixtures/segmentation/person.jpg'

  $leakedPoseFixtureHap = Join-Path $tempRoot 'leaked-pose-fixture.hap'
  $leakedPoseFixtureFiles = New-FileMap $mainEntries
  $leakedPoseFixtureFiles['module.json'] = $mainModule
  $leakedPoseFixtureFiles['resources/rawfile/fixtures/posenet/labels.json'] = 'fixture'
  New-HapFixture $leakedPoseFixtureHap $leakedPoseFixtureFiles
  Assert-GuardRejects 'non-segmentation fixture in main HAP' $leakedPoseFixtureHap $testHap `
    'Main HAP has unexpected entries: resources/rawfile/fixtures/posenet/labels.json'

  $extraTestPayloadHap = Join-Path $tempRoot 'extra-test-payload.hap'
  $extraTestPayloadFiles = New-FileMap $testEntries
  $extraTestPayloadFiles['module.json'] = $testModule
  $extraTestPayloadFiles['pack.info'] = $testPack
  $extraTestPayloadFiles['resources/rawfile/fixtures/unexpected.bin'] = 'fixture'
  New-HapFixture $extraTestPayloadHap $extraTestPayloadFiles
  Assert-GuardRejects 'unexpected payload in test HAP' $mainHap $extraTestPayloadHap `
    'ohosTest HAP has unexpected entries: resources/rawfile/fixtures/unexpected.bin'

  $duplicateTestFixtureHap = Join-Path $tempRoot 'duplicate-test-fixture.hap'
  Copy-Item -LiteralPath $testHap -Destination $duplicateTestFixtureHap
  Add-DuplicateHapEntry $duplicateTestFixtureHap 'resources/rawfile/fixtures/segmentation/person.jpg' 'duplicate'
  Assert-GuardRejects 'duplicate normalized fixture in test HAP' $mainHap $duplicateTestFixtureHap `
    'ohosTest HAP has duplicate entries: resources/rawfile/fixtures/segmentation/person.jpg'

  $copiedModelHap = Join-Path $tempRoot 'copied-model.hap'
  $copiedModelFiles = New-FileMap $testEntries
  $copiedModelFiles['module.json'] = $testModule
  $copiedModelFiles['pack.info'] = $testPack
  $copiedModelFiles['resources/rawfile/models/gesture/GestureDetector.ms'] = 'fixture'
  New-HapFixture $copiedModelHap $copiedModelFiles
  Assert-GuardRejects 'copied model in test HAP' $mainHap $copiedModelHap `
    'ohosTest HAP has unexpected entries: resources/rawfile/models/gesture/GestureDetector.ms'

  $copiedAppModelHap = Join-Path $tempRoot 'copied-app-model.hap'
  $copiedAppModelFiles = New-FileMap $testEntries
  $copiedAppModelFiles['module.json'] = $testModule
  $copiedAppModelFiles['pack.info'] = $testPack
  $copiedAppModelFiles['resources/rawfile/model/nanodet_plus_m_320.mnn'] = 'fixture'
  New-HapFixture $copiedAppModelHap $copiedAppModelFiles
  Assert-GuardRejects 'copied app model in test HAP' $mainHap $copiedAppModelHap `
    'ohosTest HAP has unexpected entries: resources/rawfile/model/nanodet_plus_m_320.mnn'

  $copiedOcrLibraryHap = Join-Path $tempRoot 'copied-ocr-library.hap'
  $copiedOcrLibraryFiles = New-FileMap $testEntries
  $copiedOcrLibraryFiles['module.json'] = $testModule
  $copiedOcrLibraryFiles['pack.info'] = $testPack
  $copiedOcrLibraryFiles['libs/arm64-v8a/libocr_mnn.so'] = 'fixture'
  New-HapFixture $copiedOcrLibraryHap $copiedOcrLibraryFiles
  Assert-GuardRejects 'copied OCR library in test HAP' $mainHap $copiedOcrLibraryHap `
    'ohosTest HAP has unexpected entries: libs/arm64-v8a/libocr_mnn.so'

  $copiedObjectDetectionLibraryHap = Join-Path $tempRoot 'copied-object-detection-library.hap'
  $copiedObjectDetectionLibraryFiles = New-FileMap $testEntries
  $copiedObjectDetectionLibraryFiles['module.json'] = $testModule
  $copiedObjectDetectionLibraryFiles['pack.info'] = $testPack
  $copiedObjectDetectionLibraryFiles['libs/arm64-v8a/libobject_detection_mnn.so'] = 'fixture'
  New-HapFixture $copiedObjectDetectionLibraryHap $copiedObjectDetectionLibraryFiles
  Assert-GuardRejects 'copied object-detection library in test HAP' $mainHap $copiedObjectDetectionLibraryHap `
    'ohosTest HAP has unexpected entries: libs/arm64-v8a/libobject_detection_mnn.so'

  $copiedStyleTransferLibraryHap = Join-Path $tempRoot 'copied-style-transfer-library.hap'
  $copiedStyleTransferLibraryFiles = New-FileMap $testEntries
  $copiedStyleTransferLibraryFiles['module.json'] = $testModule
  $copiedStyleTransferLibraryFiles['pack.info'] = $testPack
  $copiedStyleTransferLibraryFiles['libs/arm64-v8a/libstyle_transfer_mnn.so'] = 'fixture'
  New-HapFixture $copiedStyleTransferLibraryHap $copiedStyleTransferLibraryFiles
  Assert-GuardRejects 'copied style-transfer library in test HAP' $mainHap $copiedStyleTransferLibraryHap `
    'ohosTest HAP has unexpected entries: libs/arm64-v8a/libstyle_transfer_mnn.so'

  Write-Host 'HAP guard contract tests passed.'
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
