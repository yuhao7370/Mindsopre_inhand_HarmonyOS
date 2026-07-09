$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& (Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1')
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon
