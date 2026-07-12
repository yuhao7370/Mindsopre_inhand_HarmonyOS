$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& (Join-Path $PSScriptRoot 'check-i18n-strings.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-debug-ui.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-mode.ps1')
& (Join-Path $PSScriptRoot 'check-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-header-actions.ps1')
& (Join-Path $PSScriptRoot 'check-model-label-guards.ps1')
& (Join-Path $PSScriptRoot 'check-bottom-tab-icons.ps1')
& (Join-Path $PSScriptRoot 'check-me-row-icons.ps1')
& (Join-Path $PSScriptRoot 'check-poetry-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-college-chevron-icon.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-fixed-routes.ps1')
& (Join-Path $PSScriptRoot 'check-live-camera-switch-icon.ps1')
& (Join-Path $PSScriptRoot 'check-toolbar-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-back-icon.ps1')
& (Join-Path $PSScriptRoot 'check-default-picker-icon.ps1')
& (Join-Path $PSScriptRoot 'check-dance-countdown-assets.ps1')
& (Join-Path $PSScriptRoot 'check-dance-thumbnail.ps1')
& (Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1')
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor assembleHap failed with exit code $LASTEXITCODE"
}
