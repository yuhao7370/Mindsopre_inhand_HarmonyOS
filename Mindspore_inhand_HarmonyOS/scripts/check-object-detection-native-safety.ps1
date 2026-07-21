param(
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$napiPath = Join-Path $SourceRoot 'entry\src\main\cpp\object_detection_mnn_napi.cpp'
$sessionPath = Join-Path $SourceRoot 'entry\src\main\cpp\object_detection_mnn_session.cpp'
$napiSource = [IO.File]::ReadAllText($napiPath)
$sessionSource = [IO.File]::ReadAllText($sessionPath)

$emptyCheck = $napiSource.IndexOf('if (bytes.visibleLength == 0)', [StringComparison]::Ordinal)
$modelCopy = $napiSource.IndexOf('work->bytes.assign(source, source + bytes.visibleLength);', [StringComparison]::Ordinal)
if ($emptyCheck -lt 0 -or $modelCopy -lt 0 -or $emptyCheck -gt $modelCopy) {
  throw 'Object-detection native safety guard failed: empty model views must be rejected before pointer arithmetic.'
}
if ($napiSource.IndexOf('DeleteAsyncWorkOrFatal', [StringComparison]::Ordinal) -lt 0 -or
    $napiSource.IndexOf('Could not delete queued model async work.', [StringComparison]::Ordinal) -lt 0 -or
    $napiSource.IndexOf('Could not delete queued prediction async work.', [StringComparison]::Ordinal) -lt 0) {
  throw 'Object-detection native safety guard failed: async-work deletion failures need a unified fatal cleanup policy.'
}

$modelInfo = $sessionSource.IndexOf('ObjectDetectionModelInfo modelInfo', [StringComparison]::Ordinal)
$sessionSwap = $sessionSource.IndexOf('ReleaseLocked();', [StringComparison]::Ordinal)
if ($modelInfo -lt 0 -or $sessionSwap -lt 0 -or $modelInfo -gt $sessionSwap) {
  throw 'Object-detection native safety guard failed: model info must be fully constructed before session replacement.'
}

Write-Output 'Object-detection native boundary rejects empty views, preserves strong session replacement, and owns async cleanup failures.'
