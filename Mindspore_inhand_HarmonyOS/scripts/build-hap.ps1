$ErrorActionPreference = 'Stop'
$devEcoRoot = @(
  $env:DEVECO_STUDIO_HOME,
  'C:\Program Files\Huawei\DevEco Studio',
  'F:\Program Files\Huawei\DevEco Studio'
) | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'tools\hvigor\bin\hvigorw.bat') -PathType Leaf) } | Select-Object -First 1
if (-not $devEcoRoot) { throw 'DevEco Studio not found. Set DEVECO_STUDIO_HOME.' }
$env:DEVECO_SDK_HOME = Join-Path $devEcoRoot 'sdk'
$nodeHome = @(
  $env:DEVECO_NODE_HOME,
  $env:NODE_HOME,
  (Join-Path $devEcoRoot 'tools\node'),
  'C:\Program Files\Nodejs'
) | Where-Object {
    $_ -and (Test-Path -LiteralPath $_) -and (Test-Path -LiteralPath (Join-Path $_ 'bin\node.exe'))
} | Select-Object -First 1
if (-not $nodeHome) {
  $nodeHome = @(
    (Join-Path $devEcoRoot 'tools\node'),
    'C:\Program Files\Nodejs'
  ) | Where-Object {
    $_ -and (Test-Path -LiteralPath $_) -and (Test-Path -LiteralPath (Join-Path $_ 'node.exe'))
  } | Select-Object -First 1
}
if (-not $nodeHome) {
  throw 'Node.js not found. Set DEVECO_NODE_HOME or install Node in the default paths.'
}
$nodeDir = if (Test-Path -LiteralPath (Join-Path $nodeHome 'bin\node.exe')) {
  Join-Path $nodeHome 'bin'
} else {
  $nodeHome
}
$env:NODE_HOME = $nodeHome
$env:PATH = $nodeDir + ';' + $env:PATH
$env:PATH = (Join-Path $devEcoRoot 'jbr\bin') + ';' + $env:PATH
& (Join-Path $PSScriptRoot 'test-runtime-layout-closure-guard.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-layout-closure.ps1')
& (Join-Path $PSScriptRoot 'test-runtime-shared-ui-guard.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-shared-ui.ps1')
& (Join-Path $PSScriptRoot 'test-runtime-ui-evidence-guard.ps1')
& (Join-Path $PSScriptRoot 'check-i18n-strings.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-debug-ui.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-mode.ps1')
& (Join-Path $PSScriptRoot 'test-text-translation-layout-guard.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-parity.ps1')
& (Join-Path $PSScriptRoot 'check-static-gesture-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'check-posenet-still-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'check-posenet-runtime-contract.ps1')
& (Join-Path $PSScriptRoot 'check-object-photo-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-object-photo-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-style-transfer-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-style-transfer-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-still-segmentation-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-still-segmentation-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-still-scene-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-header-actions.ps1')
& (Join-Path $PSScriptRoot 'check-model-label-guards.ps1')
& (Join-Path $PSScriptRoot 'check-core-model-assets.ps1')
& (Join-Path $PSScriptRoot 'test-style-transfer-model-pair-publisher.ps1')
& (Join-Path $PSScriptRoot 'check-object-detection-fixture-license.ps1')
& (Join-Path $PSScriptRoot 'test-object-detection-fixture-license-guard.ps1')
& (Join-Path $PSScriptRoot 'check-gesture-fixtures.ps1')
& (Join-Path $PSScriptRoot 'test-gesture-fixtures-guard.ps1')
& (Join-Path $PSScriptRoot 'check-object-detection-native-safety.ps1')
& (Join-Path $PSScriptRoot 'verify-segmentation-model.ps1')
& (Join-Path $PSScriptRoot 'check-segmentation-save-readiness.ps1')
& (Join-Path $PSScriptRoot 'check-segmentation-native-boundary.ps1')
& (Join-Path $PSScriptRoot 'test-core-model-assets-guard.ps1')
& (Join-Path $PSScriptRoot 'test-native-abi-matrix.ps1')
$profile = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\entry\build-profile.json5') -Raw
$abiSection = [regex]::Match($profile, '"abiFilters"\s*:\s*\[(?<abis>.*?)\]', [Text.RegularExpressions.RegexOptions]::Singleline)
$targetAbis = [regex]::Matches($abiSection.Groups['abis'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($abi in $targetAbis) {
  & (Join-Path $PSScriptRoot 'build-mnn-ohos.ps1') -Abi $abi -VerifyOnly
  & (Join-Path $PSScriptRoot 'build-translation-xz-ohos.ps1') -Abi $abi -VerifyOnly
}
& (Join-Path $PSScriptRoot 'check-bottom-tab-icons.ps1')
& (Join-Path $PSScriptRoot 'test-arkts-image-source-guards.ps1')
& (Join-Path $PSScriptRoot 'check-me-row-icons.ps1')
& (Join-Path $PSScriptRoot 'test-native-page-ui-guard.ps1')
& (Join-Path $PSScriptRoot 'check-native-page-title-bar.ps1')
& (Join-Path $PSScriptRoot 'check-college-chevron-icon.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-fixed-routes.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-switch-icon.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-device-profile.ps1')
& (Join-Path $PSScriptRoot 'check-optional-skeleton-module.ps1')
& (Join-Path $PSScriptRoot 'check-toolbar-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-default-picker-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-countdown-assets.ps1')
& (Join-Path $PSScriptRoot 'check-dance-thumbnail.ps1')
& (Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1')
& (Join-Path $PSScriptRoot 'verify-translation-model.ps1') -ReleaseEvidencePath (Join-Path $PSScriptRoot '..\..\tools\translation\manifests\local-learning-authorization-v1.json')
$hvigor = Join-Path $devEcoRoot 'tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor assembleHap failed with exit code $LASTEXITCODE"
}
$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') -MainHapPath $mainHap
& (Join-Path $PSScriptRoot 'write-runtime-ui-build-receipt.ps1') -HapPath $mainHap
