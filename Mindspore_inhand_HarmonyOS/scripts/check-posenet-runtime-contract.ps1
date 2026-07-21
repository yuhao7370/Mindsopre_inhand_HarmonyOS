$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms'
$sourcePath = Join-Path $repoRoot 'model_sources/posenet/movenet_singlepose_lightning_float16_v4.tflite'
$labelsPath = Join-Path $repoRoot 'entry/src/ohosTest/resources/rawfile/fixtures/posenet/labels.json'
$fixtureNoticePath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/posenet/NOTICE.md'
$poseServicePath = Join-Path $repoRoot 'entry/src/main/ets/services/ai/PoseService.ets'
$factoryPath = Join-Path $repoRoot 'entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets'

function Assert-FileContract([string]$RelativePath, [long]$Bytes, [string]$Sha256) {
  $path = Join-Path $repoRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "PoseNet runtime guard failed: missing $RelativePath."
  }
  if ((Get-Item -LiteralPath $path).Length -ne $Bytes) {
    throw "PoseNet runtime guard failed: $RelativePath byte length differs."
  }
  if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $Sha256) {
    throw "PoseNet runtime guard failed: $RelativePath SHA-256 differs."
  }
}

Assert-FileContract 'model_sources/posenet/movenet_singlepose_lightning_float16_v4.tflite' 4758512 `
  '0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB'
Assert-FileContract 'entry/src/main/resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms' 9348680 `
  '972F3BE55A484B0A86A418693CF134C5BD5BD32B3418965891E7FF1DD2874677'
Assert-FileContract 'entry/src/main/resources/rawfile/posenet/skeleton_image.JPG' 589317 `
  '034E369C0DE1578FBCC0EB12E524D546405CA46AE45F340280971EB2577DFD98'
Assert-FileContract 'entry/src/main/resources/rawfile/posenet/man_standing_indoor.jpg' 132375 `
  'CC1575DA1C5CE13EC1ED67A548C67A210B033A99D4DA2DDF0CF72272498AE7A6'

$notice = Get-Content -Raw -LiteralPath $fixtureNoticePath
foreach ($marker in @(
  'Visitor7',
  'Creative Commons Attribution-ShareAlike 3.0 Unported',
  'CharlieCLC',
  'public domain',
  'oldid=1223863986',
  'oldid=1118814802',
  '034E369C0DE1578FBCC0EB12E524D546405CA46AE45F340280971EB2577DFD98',
  'CC1575DA1C5CE13EC1ED67A548C67A210B033A99D4DA2DDF0CF72272498AE7A6'
)) {
  if (-not $notice.Contains($marker)) {
    throw "PoseNet runtime guard failed: fixture NOTICE is missing $marker."
  }
}

$labels = Get-Content -Raw -LiteralPath $labelsPath | ConvertFrom-Json
if ($labels.annotationMethod -notlike 'Manually placed*' -or $labels.fixtures.Count -ne 2) {
  throw 'PoseNet runtime guard failed: exactly two manually labelled fixtures are required.'
}
$expectedFixtures = @{
  'posenet/skeleton_image.JPG' = @{ Width = 762; Height = 952; Sha256 = '034E369C0DE1578FBCC0EB12E524D546405CA46AE45F340280971EB2577DFD98' }
  'posenet/man_standing_indoor.jpg' = @{ Width = 500; Height = 752; Sha256 = 'CC1575DA1C5CE13EC1ED67A548C67A210B033A99D4DA2DDF0CF72272498AE7A6' }
}
foreach ($fixture in $labels.fixtures) {
  $expected = $expectedFixtures[$fixture.rawfilePath]
  if ($null -eq $expected -or $fixture.width -ne $expected.Width -or $fixture.height -ne $expected.Height -or
      $fixture.sha256 -cne $expected.Sha256 -or $fixture.keypoints.Count -lt 12) {
    throw "PoseNet runtime guard failed: invalid label contract for $($fixture.rawfilePath)."
  }
  $indices = @($fixture.keypoints | ForEach-Object { $_.index })
  if (($indices | Select-Object -Unique).Count -ne $indices.Count -or
      @($fixture.keypoints | Where-Object { $_.x -lt 0 -or $_.x -ge $fixture.width -or $_.y -lt 0 -or $_.y -ge $fixture.height }).Count -ne 0) {
    throw "PoseNet runtime guard failed: invalid labelled coordinates for $($fixture.rawfilePath)."
  }
}

$poseService = Get-Content -Raw -LiteralPath $poseServicePath
foreach ($marker in @(
  "moveNetModelRawfilePath: string = 'model/movenet_singlepose_lightning_float16_v4.ms'",
  'const moveNetInputSize: number = 192;',
  'export const moveNetPointCount: number = 17;',
  'new MindSporeLiteMoveNetRuntime()',
  'moveNetTensorContractMatches'
)) {
  if (-not $poseService.Contains($marker)) {
    throw "PoseNet runtime guard failed: production runtime is missing $marker."
  }
}
$factory = Get-Content -Raw -LiteralPath $factoryPath
foreach ($marker in @('new CoreVisionFallbackPoseRunner(', 'new LocalMoveNetPoseRunner({')) {
  if (-not $factory.Contains($marker)) {
    throw "PoseNet runtime guard failed: runtime factory is missing $marker."
  }
}

Write-Host 'PoseNet runtime/model/fixture contract passed.'
