[CmdletBinding()]
param(
  [string]$ModelPath = (Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\lenet_mnist.ms'),
  [string]$NoticePath = (Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\lenet_mnist.NOTICE.md')
)

$ErrorActionPreference = 'Stop'

$expectedSizeBytes = 182520
$expectedSha256 = '4CBF1D2E07C9D2BAD1B742C18AFA55996EA6CC0D335875C5D8E66C9447FD23C3'
$requiredNoticeLines = @(
  'Source SHA-256: `180A5ADAD63856AA6C79397AA319BBA82E919755B6D89B65E447851AF96EE115`.',
  'Converted artifact: `lenet_mnist.ms`, 182520 bytes, SHA-256 `4CBF1D2E07C9D2BAD1B742C18AFA55996EA6CC0D335875C5D8E66C9447FD23C3`.',
  'Converter: official MindSpore Lite 2.6.0 Linux x64 package, `converter_lite`.',
  'Converter package SHA-256: `DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E`.',
  'converter_lite SHA-256: `EB9BBA96E1022A8412021DBE4BF07C826F982EC0660E51E512787EE8350663A0`.',
  'Input: FLOAT32 NCHW `[1, 1, 28, 28]`.',
  'Output: FLOAT32 `[1, 10]`; indices 0 through 9 represent digits 0 through 9.',
  'License: project-private local learning use; the tutorial archive contains no separate trained-model license.'
)

$failures = [Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $ModelPath -PathType Leaf)) {
  $failures.Add("Missing MNIST model: $ModelPath")
} else {
  $model = Get-Item -LiteralPath $ModelPath
  if ($model.Length -ne $expectedSizeBytes) {
    $failures.Add("MNIST model size mismatch: expected $expectedSizeBytes, got $($model.Length)")
  }
  $actualSha256 = (Get-FileHash -LiteralPath $ModelPath -Algorithm SHA256).Hash
  if ($actualSha256 -cne $expectedSha256) {
    $failures.Add("MNIST model hash mismatch: expected $expectedSha256, got $actualSha256")
  }
}

if (-not (Test-Path -LiteralPath $NoticePath -PathType Leaf)) {
  $failures.Add("Missing MNIST model notice: $NoticePath")
} else {
  $notice = Get-Content -LiteralPath $NoticePath -Raw
  foreach ($requiredLine in $requiredNoticeLines) {
    if (-not $notice.Contains($requiredLine)) {
      $failures.Add("MNIST notice is missing locked contract text: $requiredLine")
    }
  }
}

if ($failures.Count -gt 0) {
  throw ($failures -join [Environment]::NewLine)
}

Write-Output "MNIST model verified: $expectedSizeBytes bytes, SHA-256 $expectedSha256"
