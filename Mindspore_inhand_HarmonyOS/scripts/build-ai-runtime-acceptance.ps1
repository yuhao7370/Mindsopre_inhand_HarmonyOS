$ErrorActionPreference = 'Stop'

$devEcoSdkCandidates = @()
if ($env:DEVECO_SDK_HOME) { $devEcoSdkCandidates += $env:DEVECO_SDK_HOME }
if ($env:DEVECO_STUDIO_HOME) { $devEcoSdkCandidates += (Join-Path $env:DEVECO_STUDIO_HOME 'sdk') }
$devEcoSdkCandidates += 'C:\Program Files\Huawei\DevEco Studio\sdk'
$devEcoSdkCandidates += 'F:\Program Files\Huawei\DevEco Studio\sdk'
$devEcoSdkHome = $null
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildProfile = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\build-profile.json5') -Raw
$abiSectionMatch = [regex]::Match($buildProfile, '"abiFilters"\s*:\s*\[(?<abis>.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $abiSectionMatch.Success) {
  throw 'Unable to read abiFilters from build-profile.json5'
}
$abis = [regex]::Matches($abiSectionMatch.Groups['abis'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if (-not $abis) { $abis = @('arm64-v8a') }
foreach ($candidate in $devEcoSdkCandidates) {
  if (-not $candidate) { continue }
  $candidatePath = [IO.Path]::GetFullPath($candidate)
  $nativeReadElf = Join-Path $candidatePath 'native\llvm\bin\llvm-readelf.exe'
  $defaultOpenHarmonyReadElf = Join-Path $candidatePath 'default\openharmony\native\llvm\bin\llvm-readelf.exe'
  $openHarmonyReadElf = Join-Path $candidatePath 'openharmony\native\llvm\bin\llvm-readelf.exe'
  if (Test-Path -LiteralPath $nativeReadElf -PathType Leaf -ErrorAction SilentlyContinue) {
    $devEcoSdkHome = $candidatePath
    break
  }
  if (Test-Path -LiteralPath $defaultOpenHarmonyReadElf -PathType Leaf -ErrorAction SilentlyContinue) {
    $devEcoSdkHome = Join-Path $candidatePath 'default\openharmony'
    break
  }
  if (Test-Path -LiteralPath $openHarmonyReadElf -PathType Leaf -ErrorAction SilentlyContinue) {
    $devEcoSdkHome = Join-Path $candidatePath 'openharmony'
    break
  }
}
if (-not $devEcoSdkHome) {
  throw 'HarmonyOS native SDK not found. Set DEVECO_SDK_HOME.'
}
$env:DEVECO_SDK_HOME = $devEcoSdkHome

& (Join-Path $PSScriptRoot 'build-hap.ps1')
foreach ($abi in $abis) {
  $gestureLibPath = Join-Path $PSScriptRoot "..\entry\build\default\intermediates\stripped_native_libs\default\$abi\libgesture_mnn.so"
  $translationLibPath = Join-Path $PSScriptRoot "..\entry\build\default\intermediates\stripped_native_libs\default\$abi\libtranslation_archive.so"
  & (Join-Path $PSScriptRoot 'verify-gesture-native-contract.ps1') -DevEcoSdkRoot $env:DEVECO_SDK_HOME -LibraryPath $gestureLibPath
  & (Join-Path $PSScriptRoot 'test-translation-xz-native-contract.ps1') -DevEcoSdkRoot $env:DEVECO_SDK_HOME -LibraryPath $translationLibPath
}
$devEcoRoot = Split-Path -Parent $env:DEVECO_SDK_HOME
$hvigor = Join-Path $devEcoRoot 'tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor entry@ohosTest assembleHap failed with exit code $LASTEXITCODE"
}

$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
$testHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') `
  -MainHapPath $mainHap -OhosTestHapPath $testHap
