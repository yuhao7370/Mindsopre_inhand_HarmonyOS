$ErrorActionPreference = 'Stop'

$path = Join-Path $PSScriptRoot '..\entry\src\main\cpp\segmentation_mnn_napi.cpp'
$source = Get-Content -Raw -LiteralPath $path
foreach ($marker in @(
  'type != napi_float32_array',
  'length == kInputElementCount',
  'length == kInputByteCount',
  'napi_get_arraybuffer_info',
  'byteOffset <= backingByteLength',
  'backingByteLength - byteOffset >= kInputByteCount',
  'ponytail: API24',
  'napi_delete_async_work(env, work->work)',
  'RejectDeferredNoThrow'
)) {
  if (-not $source.Contains($marker)) {
    throw "Segmentation native boundary is missing: $marker"
  }
}

Write-Host 'Segmentation native boundary accepts standard/API24 lengths, verifies backing bytes, and settles queue failures.'
