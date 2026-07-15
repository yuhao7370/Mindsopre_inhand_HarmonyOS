$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CoreModelAssetGuard.psm1') -Force

function Assert-TextContains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Core model asset guard failed: $Message" }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$modelRelativeRoot = 'entry/src/main/resources/rawfile/model'
$modelRoot = Join-Path $projectRoot $modelRelativeRoot
$contracts = @(
  [pscustomobject]@{ Name = 'mobilenetv2.ms'; Bytes = 14014408; Sha256 = 'F88C8C410D1148F5614994038680C245E1788C80E578D093E536572D08ECC514'; Verifier = 'verify-image-classification-model.ps1'; Downloader = 'download-image-classification-model.ps1' },
  [pscustomobject]@{ Name = 'resnet18-place365.ms'; Bytes = 45448504; Sha256 = '286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9'; Verifier = 'verify-scene-detection-model.ps1'; Downloader = 'download-scene-detection-model.ps1' },
  [pscustomobject]@{ Name = 'ssd.ms'; Bytes = 17515528; Sha256 = '0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553'; Verifier = 'verify-object-detection-model.ps1'; Downloader = 'download-object-detection-model.ps1' },
  [pscustomobject]@{ Name = 'style_predict_quant.ms'; Bytes = 3022576; Sha256 = '6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC'; Verifier = 'verify-style-transfer-models.ps1'; Downloader = 'download-style-transfer-models.ps1' },
  [pscustomobject]@{ Name = 'style_transfer_quant.ms'; Bytes = 256864; Sha256 = 'AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682'; Verifier = 'verify-style-transfer-models.ps1'; Downloader = 'download-style-transfer-models.ps1' }
)

foreach ($contract in $contracts) {
  $relativePath = "$modelRelativeRoot/$($contract.Name)"
  $modelPath = Join-Path $modelRoot $contract.Name
  if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
    throw "Core model asset guard failed: missing $relativePath."
  }
  $actualBytes = (Get-Item -LiteralPath $modelPath).Length
  if ($actualBytes -ne $contract.Bytes) {
    throw "Core model asset guard failed: $($contract.Name) has $actualBytes bytes; expected $($contract.Bytes)."
  }
  $actualSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
  if ($actualSha256 -cne $contract.Sha256) {
    throw "Core model asset guard failed: $($contract.Name) SHA-256 is $actualSha256; expected $($contract.Sha256)."
  }

  & git -C $projectRoot check-ignore --no-index -q -- $relativePath
  if ($LASTEXITCODE -eq 0) {
    throw "Core model asset guard failed: stable model is ignored: $relativePath."
  }
  & git -C $projectRoot ls-files --error-unmatch -- $relativePath *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Core model asset guard failed: stable model is not tracked: $relativePath."
  }
}

foreach ($partialProbe in @('probe.ms.download', 'probe.ms.download.0123456789abcdef')) {
  & git -C $projectRoot check-ignore --no-index -q -- "$modelRelativeRoot/$partialProbe"
  if ($LASTEXITCODE -ne 0) {
    throw "Core model asset guard failed: request partial must remain ignored: $partialProbe."
  }
}

foreach ($contract in $contracts) {
  $relativePath = "$modelRelativeRoot/$($contract.Name)"
  $attributes = @(& git -C $projectRoot check-attr text diff -- $relativePath)
  if ($LASTEXITCODE -ne 0 -or $attributes -notcontains "$relativePath`: text: unset" -or
      $attributes -notcontains "$relativePath`: diff: unset") {
    throw "Core model asset guard failed: $($contract.Name) must resolve to -text -diff attributes."
  }
}

$ensurePath = Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1'
$ensureAst = Read-CoreGuardPowerShellAst $ensurePath
$requiredVerifiers = @(
  'verify-image-classification-model.ps1',
  'verify-image-classification-labels.ps1',
  'verify-object-detection-model.ps1',
  'verify-object-detection-labels.ps1',
  'verify-scene-detection-model.ps1',
  'verify-style-transfer-models.ps1'
)
foreach ($verifier in $requiredVerifiers) {
  Assert-CoreGuardExecutableCommand $ensureAst "& (Join-Path `$PSScriptRoot '$verifier')" "ensure-mindspore-models.ps1 must execute $verifier."
}
$ensureInvocations = @($ensureAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    $node.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Ampersand
}, $true))
if ($ensureInvocations.Count -ne $requiredVerifiers.Count) {
  throw "Core model asset guard failed: ensure-mindspore-models.ps1 must execute only the six approved verifiers; found $($ensureInvocations.Count) invocations."
}

foreach ($contract in $contracts) {
  $verifierAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot $contract.Verifier)
  if ($contract.Verifier -eq 'verify-style-transfer-models.ps1') {
    Assert-CoreGuardObjectArrayContract $verifierAst 'models' $contract.Name $contract.Bytes $contract.Sha256 `
      "$($contract.Verifier) model contract."
  } else {
    Assert-CoreGuardAssignmentLiteral $verifierAst 'expectedModelSize' $contract.Bytes "$($contract.Verifier) must pin $($contract.Name) byte length."
    Assert-CoreGuardAssignmentLiteral $verifierAst 'expectedModelSha256' $contract.Sha256 "$($contract.Verifier) must pin $($contract.Name) SHA-256."
  }
  Assert-CoreGuardExecutableCommand $verifierAst 'Get-FileHash -LiteralPath $modelPath -Algorithm SHA256' "$($contract.Verifier) must hash the executable model path."

  $downloaderAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot $contract.Downloader)
  if ($contract.Downloader -eq 'download-style-transfer-models.ps1') {
    Assert-CoreGuardObjectArrayContract $downloaderAst 'models' $contract.Name $contract.Bytes $contract.Sha256 `
      "$($contract.Downloader) model contract."
  } else {
    Assert-CoreGuardAssignmentLiteral $downloaderAst 'expectedModelSize' $contract.Bytes "$($contract.Downloader) must pin $($contract.Name) byte length."
    Assert-CoreGuardAssignmentLiteral $downloaderAst 'expectedModelSha256' $contract.Sha256 "$($contract.Downloader) must pin $($contract.Name) SHA-256."
  }
}

foreach ($downloaderName in @(
  'download-image-classification-model.ps1',
  'download-object-detection-model.ps1',
  'download-scene-detection-model.ps1',
  'download-style-transfer-models.ps1'
)) {
  $downloaderAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot $downloaderName)
  $guidCount = if ($downloaderName -eq 'download-scene-detection-model.ps1') { 2 } else { 1 }
  Assert-CoreGuardExecutableMemberCall $downloaderAst '[System.Guid]::NewGuid().ToString(''N'')' "$downloaderName must create request-private GUID names." $guidCount
  Assert-CoreGuardExecutableCommand $downloaderAst 'Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256' "$downloaderName must validate the staged same-directory temp."
  Assert-CoreGuardExecutableMemberCall $downloaderAst '[System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)' "$downloaderName must atomically replace an existing stable model."
  Assert-CoreGuardExecutableMemberCall $downloaderAst '[System.IO.File]::Move($tmpPath, $modelPath)' "$downloaderName must atomically publish when the stable model is absent."
  Assert-CoreGuardFinallyCleanup $downloaderAst $downloaderName
  Assert-CoreGuardNoStableMutation $downloaderAst $downloaderName
}

$licensePath = Join-Path $modelRoot 'LICENSE-Apache-2.0.txt'
$referenceLicensePath = Join-Path $projectRoot 'entry/src/main/cpp/third_party/MNN/LICENSE.txt'
if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
  throw 'Core model asset guard failed: missing LICENSE-Apache-2.0.txt.'
}
if ((Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash -cne
    (Get-FileHash -LiteralPath $referenceLicensePath -Algorithm SHA256).Hash) {
  throw 'Core model asset guard failed: model license must contain the complete tracked Apache-2.0 text.'
}

$noticePath = Join-Path $modelRoot 'NOTICE.md'
if (-not (Test-Path -LiteralPath $noticePath -PathType Leaf)) {
  throw 'Core model asset guard failed: missing model NOTICE.md.'
}
$notice = Get-Content -Raw -LiteralPath $noticePath
foreach ($marker in @(
  'MindSpore Model Zoo',
  'Apache-2.0',
  'non-commercial research and educational use',
  'private local learning',
  'af40795ebb2a295d87cd6dcd1383782a78776cda',
  'Copyright 2025 Huawei Device Co., Ltd.',
  'no additional NOTICE',
  'https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms',
  'https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms',
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms',
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms',
  'https://gitee.com/harmonyos_samples/MSLiteSceneRecognition'
)) {
  Assert-TextContains $notice $marker "NOTICE.md is missing provenance marker: $marker."
}
foreach ($contract in $contracts) {
  Assert-TextContains $notice $contract.Name "NOTICE.md is missing $($contract.Name)."
  Assert-TextContains $notice ([string]$contract.Bytes) "NOTICE.md is missing $($contract.Name) byte length."
  Assert-TextContains $notice $contract.Sha256 "NOTICE.md is missing $($contract.Name) SHA-256."
}

$buildAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot 'build-hap.ps1')
Assert-CoreGuardExecutableCommand $buildAst "& (Join-Path `$PSScriptRoot 'check-core-model-assets.ps1')" 'build-hap.ps1 must execute the core model asset guard.'
Assert-CoreGuardExecutableCommand $buildAst "& (Join-Path `$PSScriptRoot 'test-core-model-assets-guard.ps1')" 'build-hap.ps1 must execute core model guard fixtures.'
Assert-CoreGuardExecutableCommand $buildAst "& (Join-Path `$PSScriptRoot 'ensure-mindspore-models.ps1')" 'build-hap.ps1 must execute verifier-only model ensure wiring.'
Assert-CoreGuardNoDownloaderCommand $buildAst 'normal build'

$hapVerifierAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1')
$hapFixtureAst = Read-CoreGuardPowerShellAst (Join-Path $PSScriptRoot 'test-verify-ai-runtime-haps.ps1')
foreach ($entry in @(
  'resources/rawfile/model/mobilenetv2.ms',
  'resources/rawfile/model/resnet18-place365.ms',
  'resources/rawfile/model/ssd.ms',
  'resources/rawfile/model/style_predict_quant.ms',
  'resources/rawfile/model/style_transfer_quant.ms',
  'resources/rawfile/model/LICENSE-Apache-2.0.txt',
  'resources/rawfile/model/NOTICE.md'
)) {
  Assert-CoreGuardStringArrayContains $hapVerifierAst 'resourceEntries' $entry "main HAP verifier is missing $entry."
  Assert-CoreGuardStringArrayContains $hapFixtureAst 'mainEntries' $entry "HAP fixture is missing $entry."
}
Assert-CoreGuardExecutableCommand $hapVerifierAst 'Assert-HapPayloadHashes $MainHapPath $payloads' 'main HAP must reuse exact payload hash verification.'
Assert-CoreGuardAssignmentLiteral $hapFixtureAst 'tamperedAppModelEntry' 'resources/rawfile/model/ssd.ms' 'HAP fixture must reject a tampered core model.'

$entryBuildProfile = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'entry/build-profile.json5')
$testHapExclusions = @(Get-CoreGuardJson5ArrayForNamedObject $entryBuildProfile 'ohosTest' 'ignoreResourcePattern')
foreach ($testHapExclusion in @('*.ms', 'NOTICE.md', 'LICENSE-Apache-2.0.txt')) {
  if ($testHapExclusions -cnotcontains $testHapExclusion) {
    throw "Core model asset guard failed: ohosTest ignoreResourcePattern must exclude $testHapExclusion."
  }
}

Write-Host 'Core model asset guard passed.'
