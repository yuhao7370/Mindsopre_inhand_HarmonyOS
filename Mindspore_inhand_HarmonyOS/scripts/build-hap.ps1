$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& (Join-Path $PSScriptRoot 'check-i18n-strings.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-debug-ui.ps1')
& (Join-Path $PSScriptRoot 'check-text-translation-input-mode.ps1')
& (Join-Path $PSScriptRoot 'check-feature-runtime-view-ids.ps1')
& (Join-Path $PSScriptRoot 'check-model-label-guards.ps1')
& (Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1')
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor assembleHap failed with exit code $LASTEXITCODE"
}
