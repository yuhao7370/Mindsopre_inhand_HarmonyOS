param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$root = Join-Path $SourceRoot 'entry\src\ohosTest\resources\rawfile\fixtures\gesture'
$noticePath = Join-Path $root 'NOTICE.md'
$contracts = @(
  @{ Name = 'four.jpg'; Bytes = 22147; Hash = '197F8A11CB74A2ECFF8AA106271E5D3088A64C8FEA691DC081385FB8BA4A6AA0' },
  @{ Name = 'solid_gray.png'; Bytes = 1173; Hash = '69A6B38DBE20F182F658D7DE3C545F6BECCF892C951BC008532543517D2C8DFE' }
)

if (-not (Test-Path -LiteralPath $noticePath -PathType Leaf)) {
  throw 'Gesture fixture guard failed: NOTICE.md is missing.'
}
if (Test-Path -LiteralPath (Join-Path $root 'open_palm.png')) {
  throw 'Gesture fixture guard failed: obsolete unlicensed open_palm.png is present.'
}
$notice = [IO.File]::ReadAllText($noticePath)
foreach ($marker in @(
  '0ad5a71bcdff3d756dc5b07f93765aaeb4152538',
  'License: Apache License 2.0',
  'category 3 (`Four`)',
  'expected production result is zero detections'
)) {
  if ($notice.IndexOf($marker, [StringComparison]::Ordinal) -lt 0) {
    throw "Gesture fixture guard failed: NOTICE.md is missing $marker."
  }
}
foreach ($contract in $contracts) {
  $path = Join-Path $root $contract.Name
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Gesture fixture guard failed: missing $($contract.Name)."
  }
  if ((Get-Item -LiteralPath $path).Length -ne $contract.Bytes) {
    throw "Gesture fixture guard failed: $($contract.Name) size mismatch."
  }
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  if ($hash -cne $contract.Hash -or $notice.IndexOf($contract.Hash, [StringComparison]::Ordinal) -lt 0) {
    throw "Gesture fixture guard failed: $($contract.Name) SHA-256 mismatch."
  }
}

Write-Output 'Gesture fixture provenance, hashes, and positive/negative oracle are valid.'
