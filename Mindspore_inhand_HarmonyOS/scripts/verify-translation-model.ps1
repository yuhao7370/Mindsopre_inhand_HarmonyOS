[CmdletBinding()]
param(
  [string]$StageRoot = '',
  [string]$PackageManifestPath = '',
  [string]$NativeDecompressorPath = '',
  [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '..'))
if (-not $StageRoot) {
  $StageRoot = Join-Path $projectRoot 'entry\src\main\resources\rawfile\models\translation'
}
if (-not $PackageManifestPath) {
  $PackageManifestPath = Join-Path $repositoryRoot 'tools\translation\manifests\final-package-v1.json'
}
if (-not $NativeDecompressorPath) {
  $NativeDecompressorPath = Join-Path $projectRoot 'entry\libs\arm64-v8a\libtranslation_archive.so'
}
$StageRoot = [IO.Path]::GetFullPath($StageRoot)
$PackageManifestPath = [IO.Path]::GetFullPath($PackageManifestPath)
$NativeDecompressorPath = [IO.Path]::GetFullPath($NativeDecompressorPath)
$runtimeManifestPath = Join-Path $StageRoot 'manifest.json'
$archivePath = Join-Path $StageRoot 'translation-models.tar.xz'
$packageVerifier = Join-Path $repositoryRoot 'tools\translation\verify_translation_package.py'

function Assert-ExactProperties([object]$Object, [string[]]$Expected, [string]$Path) {
  if ($Object -isnot [PSCustomObject]) { throw "$Path must be a JSON object." }
  $actual = @($Object.PSObject.Properties.Name | Sort-Object)
  $wanted = @($Expected | Sort-Object)
  if ($actual.Count -ne $wanted.Count -or ($actual -join '|') -cne ($wanted -join '|')) {
    throw "$Path properties mismatch: expected $($wanted -join ', '), got $($actual -join ', ')."
  }
}

function Assert-JsonInteger([object]$Value, [int64]$Expected, [string]$Path) {
  if (($Value -isnot [int32] -and $Value -isnot [int64]) -or [int64]$Value -ne $Expected) {
    throw "$Path must be the JSON integer $Expected."
  }
}

function Assert-PositiveInteger([object]$Value, [string]$Path) {
  if (($Value -isnot [int32] -and $Value -isnot [int64]) -or [int64]$Value -le 0) {
    throw "$Path must be a positive JSON integer."
  }
}

function Assert-String([object]$Value, [string]$Expected, [string]$Path) {
  if ($Value -isnot [string] -or $Value -cne $Expected) {
    throw "$Path must be the JSON string '$Expected'."
  }
}

function Assert-Sha256([object]$Value, [string]$Path) {
  if ($Value -isnot [string] -or $Value -cnotmatch '^[0-9A-Fa-f]{64}$') {
    throw "$Path must be a SHA-256 string."
  }
}

function Assert-Shape([object]$Value, [string]$Expected, [string]$Path) {
  if ($Value -isnot [System.Array]) { throw "$Path must be a JSON array." }
  $dimensions = @()
  for ($index = 0; $index -lt $Value.Count; $index++) {
    $dimension = $Value[$index]
    if (($dimension -isnot [int32] -and $dimension -isnot [int64]) -or [int64]$dimension -le 0) {
      throw "$Path[$index] must be a positive JSON integer."
    }
    $dimensions += [string]$dimension
  }
  if (($dimensions -join ',') -cne $Expected) {
    throw "$Path mismatch: expected [$Expected], got [$($dimensions -join ',')]."
  }
}

function Assert-Tensors([object]$Value, [string[]]$Expected, [string]$Path) {
  if ($Value -isnot [System.Array] -or $Value.Count -ne $Expected.Count) {
    throw "$Path must contain exactly $($Expected.Count) tensors."
  }
  for ($index = 0; $index -lt $Expected.Count; $index++) {
    $tensor = $Value[$index]
    Assert-ExactProperties $tensor @('name', 'dtype', 'shape') "$Path[$index]"
    $parts = $Expected[$index].Split('|')
    Assert-String $tensor.name $parts[0] "$Path[$index].name"
    Assert-String $tensor.dtype $parts[1] "$Path[$index].dtype"
    Assert-Shape $tensor.shape $parts[2] "$Path[$index].shape"
  }
}

function Invoke-Checked([string]$Executable, [string[]]$Arguments, [string]$Label) {
  $previous = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $Executable @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($exitCode -ne 0) { throw "$Label failed ($exitCode):`n$($output.Trim())" }
  return $output.Trim()
}

if (-not (Test-Path -LiteralPath $StageRoot -PathType Container)) {
  throw "Missing translation asset directory: $StageRoot"
}
foreach ($path in @($PackageManifestPath, $runtimeManifestPath, $archivePath, $NativeDecompressorPath, $packageVerifier)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing translation package input: $path" }
}

Push-Location $repositoryRoot
try {
  $packageResult = Invoke-Checked $Python @(
    $packageVerifier, '--manifest', $PackageManifestPath, '--stage', $StageRoot,
    '--decompressor', $NativeDecompressorPath
  ) 'Task 1 translation package verifier'
} finally {
  Pop-Location
}

$manifest = [IO.File]::ReadAllText($runtimeManifestPath) | ConvertFrom-Json
Assert-ExactProperties $manifest @('schemaVersion', 'vocabulary', 'archive', 'graphs') '$'
Assert-JsonInteger $manifest.schemaVersion 1 '$.schemaVersion'

$vocabulary = $manifest.vocabulary
Assert-ExactProperties $vocabulary @('size', 'eos', 'unk', 'pad', 'decoderStart', 'toEnglish', 'toChinese') '$.vocabulary'
Assert-JsonInteger $vocabulary.size 32003 '$.vocabulary.size'
Assert-JsonInteger $vocabulary.eos 0 '$.vocabulary.eos'
Assert-JsonInteger $vocabulary.unk 1 '$.vocabulary.unk'
Assert-JsonInteger $vocabulary.pad 32000 '$.vocabulary.pad'
Assert-JsonInteger $vocabulary.decoderStart 32000 '$.vocabulary.decoderStart'
Assert-JsonInteger $vocabulary.toEnglish 32001 '$.vocabulary.toEnglish'
Assert-JsonInteger $vocabulary.toChinese 32002 '$.vocabulary.toChinese'

$archive = $manifest.archive
Assert-ExactProperties $archive @('file', 'size', 'sha256', 'cacheKey') '$.archive'
Assert-String $archive.file 'translation-models.tar.xz' '$.archive.file'
Assert-PositiveInteger $archive.size '$.archive.size'
Assert-Sha256 $archive.sha256 '$.archive.sha256'
Assert-String $archive.cacheKey 'ARCHIVE_SHA256' '$.archive.cacheKey'
if ([int64]$archive.size -gt 32MB) { throw '$.archive.size exceeds 32 MiB.' }
$actualArchive = Get-Item -LiteralPath $archivePath
if ($actualArchive.Length -ne [int64]$archive.size) { throw 'Translation archive size differs from manifest.' }
$actualArchiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($actualArchiveHash -cne ([string]$archive.sha256).ToUpperInvariant()) { throw 'Translation archive hash differs from manifest.' }

if ($manifest.graphs -isnot [System.Array] -or $manifest.graphs.Count -ne 3) {
  throw '$.graphs must contain exactly three graph objects.'
}
$expectedFiles = @('encoder.ms', 'decoder_prefill.ms', 'decoder_step.ms')
$expectedInputs = @(
  @('input_ids|INT32|1,128', 'attention_mask|INT32|1,128'),
  @('decoder_input_ids|INT32|1,1', 'encoder_hidden_states|FLOAT32|1,128,256', 'encoder_attention_mask|INT32|1,128'),
  @('decoder_input_ids|INT32|1,1', 'position_id|INT32|1', 'self_attention_mask|INT32|1,128', 'cross_attention_mask|INT32|1,128',
    'past_key_0|FLOAT32|1,8,127,32', 'past_value_0|FLOAT32|1,8,127,32', 'cross_key_0|FLOAT32|1,8,128,32', 'cross_value_0|FLOAT32|1,8,128,32',
    'past_key_1|FLOAT32|1,8,127,32', 'past_value_1|FLOAT32|1,8,127,32', 'cross_key_1|FLOAT32|1,8,128,32', 'cross_value_1|FLOAT32|1,8,128,32')
)
$expectedOutputs = @(
  @('last_hidden_state|FLOAT32|1,128,256'),
  @('logits|FLOAT32|1,32003', 'self_key_0|FLOAT32|1,8,1,32', 'self_value_0|FLOAT32|1,8,1,32', 'cross_key_0|FLOAT32|1,8,128,32', 'cross_value_0|FLOAT32|1,8,128,32',
    'self_key_1|FLOAT32|1,8,1,32', 'self_value_1|FLOAT32|1,8,1,32', 'cross_key_1|FLOAT32|1,8,128,32', 'cross_value_1|FLOAT32|1,8,128,32'),
  @('logits|FLOAT32|1,32003', 'new_key_0|FLOAT32|1,8,1,32', 'new_value_0|FLOAT32|1,8,1,32', 'new_key_1|FLOAT32|1,8,1,32', 'new_value_1|FLOAT32|1,8,1,32')
)
$outputBytes = [int64]0
for ($index = 0; $index -lt 3; $index++) {
  $graph = $manifest.graphs[$index]
  $path = "$.graphs[$index]"
  Assert-ExactProperties $graph @('file', 'size', 'sha256', 'inputs', 'outputs') $path
  Assert-String $graph.file $expectedFiles[$index] "$path.file"
  Assert-PositiveInteger $graph.size "$path.size"
  Assert-Sha256 $graph.sha256 "$path.sha256"
  Assert-Tensors $graph.inputs $expectedInputs[$index] "$path.inputs"
  Assert-Tensors $graph.outputs $expectedOutputs[$index] "$path.outputs"
  $outputBytes += [int64]$graph.size
}
if ($outputBytes -gt 60MB) { throw 'Uncompressed translation graphs exceed 60 MiB.' }

$archiveVerifierCode = @'
import json, sys
from pathlib import Path
from tools.translation.build_translation_archive import verify_archive
runtime = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
contract = {
    'schemaVersion': 1,
    'members': [{'name': graph['file'], 'size': graph['size'], 'sha256': graph['sha256']} for graph in runtime['graphs']],
}
verify_archive(Path(sys.argv[1]), contract)
'@
Push-Location $repositoryRoot
try {
  $archiveResult = Invoke-Checked $Python @('-c', $archiveVerifierCode, $archivePath, $runtimeManifestPath) 'Task 1 translation archive verifier'
} finally {
  Pop-Location
}

Write-Output "Translation package verified: $packageResult; archive=$actualArchiveHash; unpackedBytes=$outputBytes"
