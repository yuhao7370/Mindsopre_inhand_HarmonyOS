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

function New-FileMap([string[]]$Entries) {
  $files = @{}
  foreach ($entry in $Entries) { $files[$entry] = 'fixture' }
  $files['module.json'] = '{}'
  return $files
}

function Assert-GuardRejects([string]$Label, [string]$MainHapPath, [string]$OhosTestHapPath) {
  $rejected = $false
  try {
    & $guard -MainHapPath $MainHapPath -OhosTestHapPath $OhosTestHapPath *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) { throw "Guard unexpectedly accepted: $Label" }
  Write-Host "Rejected invalid fixture: $Label"
}

$mainEntries = @(
  'module.json',
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
  'libs/arm64-v8a/libtranslation_archive.so'
)

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
  $testFiles = New-FileMap $testEntries
  $testFiles['module.json'] = $testModule
  $testFiles['pack.info'] = $testPack
  New-HapFixture $mainHap $mainFiles
  New-HapFixture $testHap $testFiles
  & $guard -MainHapPath $mainHap -OhosTestHapPath $testHap

  $missingMainHap = Join-Path $tempRoot 'missing-main-entry.hap'
  New-HapFixture $missingMainHap (New-FileMap @($mainEntries | Select-Object -SkipLast 1))
  Assert-GuardRejects 'missing main entry' $missingMainHap $testHap

  $wrongModuleHap = Join-Path $tempRoot 'wrong-test-module.hap'
  $wrongModuleFiles = New-FileMap $testEntries
  $wrongModuleFiles['module.json'] = $testModule.Replace('entry_test', 'other_test')
  $wrongModuleFiles['pack.info'] = $testPack
  New-HapFixture $wrongModuleHap $wrongModuleFiles
  Assert-GuardRejects 'wrong test module name' $mainHap $wrongModuleHap

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
  Assert-GuardRejects 'missing paired entry module' $mainHap $missingEntryHap

  $copiedModelHap = Join-Path $tempRoot 'copied-model.hap'
  $copiedModelFiles = New-FileMap $testEntries
  $copiedModelFiles['module.json'] = $testModule
  $copiedModelFiles['pack.info'] = $testPack
  $copiedModelFiles['resources/rawfile/models/gesture/GestureDetector.ms'] = 'fixture'
  New-HapFixture $copiedModelHap $copiedModelFiles
  Assert-GuardRejects 'copied model in test HAP' $mainHap $copiedModelHap

  $copiedAppModelHap = Join-Path $tempRoot 'copied-app-model.hap'
  $copiedAppModelFiles = New-FileMap $testEntries
  $copiedAppModelFiles['module.json'] = $testModule
  $copiedAppModelFiles['pack.info'] = $testPack
  $copiedAppModelFiles['resources/rawfile/model/ssd.ms'] = 'fixture'
  New-HapFixture $copiedAppModelHap $copiedAppModelFiles
  Assert-GuardRejects 'copied app model in test HAP' $mainHap $copiedAppModelHap

  Write-Host 'HAP guard contract tests passed.'
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
