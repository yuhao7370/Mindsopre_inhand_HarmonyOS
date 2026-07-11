$ErrorActionPreference = 'Stop'

$ensurePath = Join-Path $PSScriptRoot 'ensure-mindspore-models.ps1'
if (-not (Test-Path -LiteralPath $ensurePath)) {
  throw "Missing model ensure script: $ensurePath"
}

$content = Get-Content -LiteralPath $ensurePath -Raw
$requiredVerifiers = @(
  'verify-image-classification-labels.ps1',
  'verify-object-detection-labels.ps1'
)

foreach ($verifier in $requiredVerifiers) {
  if ($content.IndexOf($verifier) -lt 0) {
    throw "ensure-mindspore-models.ps1 must call $verifier."
  }
}

Write-Host 'model label guard wiring is attached to ensure-mindspore-models.ps1'
