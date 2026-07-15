$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& (Join-Path $PSScriptRoot 'check-i18n-strings.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-debug-ui.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-mode.ps1')
& (Join-Path $PSScriptRoot 'test-text-translation-layout-guard.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-parity.ps1')
& (Join-Path $PSScriptRoot 'check-static-gesture-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'check-posenet-still-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'check-object-photo-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-object-photo-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-style-transfer-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-style-transfer-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-still-segmentation-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-still-segmentation-layout-parity-guard.ps1')
& (Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-header-actions.ps1')
& (Join-Path $PSScriptRoot 'check-model-label-guards.ps1')
& (Join-Path $PSScriptRoot 'check-core-model-assets.ps1')
& (Join-Path $PSScriptRoot 'test-core-model-assets-guard.ps1')
& (Join-Path $PSScriptRoot 'check-bottom-tab-icons.ps1')
& (Join-Path $PSScriptRoot 'check-me-row-icons.ps1')
& (Join-Path $PSScriptRoot 'check-poetry-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-college-chevron-icon.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-fixed-routes.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-switch-icon.ps1')
& (Join-Path $PSScriptRoot 'check-optional-skeleton-module.ps1')
& (Join-Path $PSScriptRoot 'check-toolbar-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-default-picker-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-countdown-assets.ps1')
& (Join-Path $PSScriptRoot 'check-dance-thumbnail.ps1')
& (Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1')
& (Join-Path $PSScriptRoot 'verify-translation-model.ps1') -ReleaseEvidencePath (Join-Path $PSScriptRoot '..\..\tools\translation\manifests\local-learning-authorization-v1.json')
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor assembleHap failed with exit code $LASTEXITCODE"
}
$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') -MainHapPath $mainHap
