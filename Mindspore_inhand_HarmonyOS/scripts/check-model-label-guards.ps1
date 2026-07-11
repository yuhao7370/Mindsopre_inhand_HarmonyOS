$ErrorActionPreference = 'Stop'

$ensurePath = Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1'
if (-not (Test-Path -LiteralPath $ensurePath)) {
  throw "Missing model ensure script: $ensurePath"
}

$ensureContent = Get-Content -LiteralPath $ensurePath -Raw
$requiredVerifiers = @(
  'verify-image-classification-labels.ps1',
  'verify-object-detection-labels.ps1'
)

foreach ($verifier in $requiredVerifiers) {
  if ($ensureContent.IndexOf($verifier) -lt 0) {
    throw "ensure-mindspore-models.ps1 must call $verifier."
  }
}

$verificationContent = $ensureContent
foreach ($verifier in $requiredVerifiers) {
  $verifierPath = Join-Path $PSScriptRoot $verifier
  if (-not (Test-Path -LiteralPath $verifierPath)) {
    throw "Missing label verifier script: $verifierPath"
  }
  $verificationContent += Get-Content -LiteralPath $verifierPath -Raw
}

$requiredLabelReferences = @(
  'labels/zh_CN/image_category_old.txt',
  'labels/zh_CN/object_category.txt'
)

foreach ($reference in $requiredLabelReferences) {
  if ($verificationContent.IndexOf($reference) -lt 0) {
    throw "model label verification must reference $reference."
  }
}

Write-Host 'model label guard wiring is attached to ensure-mindspore-models.ps1'
