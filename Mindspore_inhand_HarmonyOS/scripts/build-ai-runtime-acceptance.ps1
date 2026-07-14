$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH

& (Join-Path $PSScriptRoot 'build-hap.ps1')
& (Join-Path $PSScriptRoot 'verify-gesture-native-contract.ps1') -LibraryPath (Join-Path $PSScriptRoot '..\entry\build\default\intermediates\stripped_native_libs\default\arm64-v8a\libgesture_mnn.so')
& (Join-Path $PSScriptRoot 'test-translation-xz-native-contract.ps1') -LibraryPath (Join-Path $PSScriptRoot '..\entry\build\default\intermediates\stripped_native_libs\default\arm64-v8a\libtranslation_archive.so')
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor entry@ohosTest assembleHap failed with exit code $LASTEXITCODE"
}

$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
$testHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') `
  -MainHapPath $mainHap -OhosTestHapPath $testHap
