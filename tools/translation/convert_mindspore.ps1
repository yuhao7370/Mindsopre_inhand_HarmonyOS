param(
  [Parameter(Mandatory = $true)][string]$Python,
  [Parameter(Mandatory = $true)][string]$OnnxDir,
  [Parameter(Mandatory = $true)][string]$OutputRoot,
  [Parameter(Mandatory = $true)][string]$Contract,
  [ValidateSet('prototype', 'final')][string]$Profile = 'prototype',
  [Parameter(Mandatory = $true)][string]$Converter,
  [Parameter(Mandatory = $true)][string]$Benchmark,
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][string]$CxxCompiler,
  [string]$EvidenceFixtureRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
if ($resolvedOutput.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Generated ONNX/MS artifacts must stay outside the repository.'
}
foreach ($path in @($Python, $Converter, $Benchmark, $CxxCompiler, $Contract)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required file: $path" }
}
foreach ($name in @('encoder.onnx', 'decoder_prefill.onnx', 'decoder_step.onnx')) {
  if (-not (Test-Path -LiteralPath (Join-Path $OnnxDir $name) -PathType Leaf)) { throw "Missing ONNX graph: $name" }
}

$converterToolRoot = Split-Path (Split-Path $Converter -Parent) -Parent
$converterLib = Join-Path $converterToolRoot 'lib'
$runtimeLib = Join-Path $RuntimeRoot 'runtime\lib'
$runtimeGlog = Join-Path $RuntimeRoot 'runtime\third_party\glog'
$compilerBin = Split-Path $CxxCompiler -Parent
$env:PATH = "$converterLib;$runtimeLib;$runtimeGlog;$compilerBin;$env:PATH"

& $Python (Join-Path $PSScriptRoot 'export_marian_smoke.py') --checkpoint $OnnxDir --output-root $OnnxDir --contract $Contract --profile $Profile --inspect-only
if ($LASTEXITCODE -ne 0) { throw 'ONNX contract inspection failed.' }

New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$floatDir = Join-Path $resolvedOutput 'float'
$w8Dir = Join-Path $resolvedOutput 'w8'
New-Item -ItemType Directory -Force -Path $floatDir, $w8Dir | Out-Null
$quantConfig = Join-Path $resolvedOutput 'weight-quant-w8.cfg'
$quantText = "[common_quant_param]`nquant_type=WEIGHT_QUANT`nbit_num=8`nmin_quant_weight_size=0`nmin_quant_weight_channel=0`n"
[IO.File]::WriteAllText($quantConfig, $quantText, (New-Object Text.UTF8Encoding($false)))
if ([IO.File]::ReadAllText($quantConfig) -ne $quantText) { throw 'W8 quantization configuration changed unexpectedly.' }

function Invoke-Checked([string]$Label, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE" }
}

function Convert-Graph([string]$Graph, [string]$OutputName, [bool]$UseNchw, [bool]$Quantized) {
  $source = Join-Path $OnnxDir "$Graph.onnx"
  $targetDir = if ($Quantized) { $w8Dir } else { $floatDir }
  $target = Join-Path $targetDir $OutputName
  $arguments = @('--fmk=ONNX', "--modelFile=$source", "--outputFile=$target", '--saveType=MINDIR_LITE', '--optimize=general')
  if ($UseNchw) { $arguments += @('--inputDataFormat=NCHW', '--outputDataFormat=NCHW') }
  if ($Quantized) { $arguments += "--configFile=$quantConfig" }
  Invoke-Checked "convert $Graph" { & $Converter $arguments }
  if (-not (Test-Path -LiteralPath "$target.ms" -PathType Leaf)) { throw "Converter did not create $target.ms" }
}

foreach ($quantized in @($false, $true)) {
  Convert-Graph 'encoder' 'encoder' $false $quantized
  Convert-Graph 'decoder_prefill' 'decoder_prefill' $true $quantized
  Convert-Graph 'decoder_step' 'decoder_step' $true $quantized
}

foreach ($name in @('encoder', 'decoder_prefill', 'decoder_step')) {
  Invoke-Checked "benchmark $name" { & $Benchmark "--modelFile=$(Join-Path $w8Dir "$name.ms")" '--loopCount=1' '--warmUpLoopCount=0' '--numThreads=2' }
}

$smokeExe = Join-Path $resolvedOutput 'mindspore_translation_smoke.exe'
$descriptorHeader = Join-Path $resolvedOutput 'translation_runtime_contract.h'
Invoke-Checked 'generate MindSpore runtime descriptor contract' {
  & $Python (Join-Path $PSScriptRoot 'generate_mindspore_contract.py') --contract $Contract --profile $Profile --output $descriptorHeader
}
$includeRoot = Join-Path $RuntimeRoot 'runtime'
Invoke-Checked 'compile MindSpore cache-loop smoke' {
  & $CxxCompiler '-std=c++17' '-O2' "-I$includeRoot" "-I$resolvedOutput" (Join-Path $PSScriptRoot 'mindspore_translation_smoke.cpp') "-L$runtimeLib" '-lmindspore-lite' '-o' $smokeExe
}
$smokeArguments = @((Join-Path $w8Dir 'encoder.ms'), (Join-Path $w8Dir 'decoder_prefill.ms'), (Join-Path $w8Dir 'decoder_step.ms'))
if ($EvidenceFixtureRoot) { $smokeArguments += $EvidenceFixtureRoot }
$mindSporeOutput = & $smokeExe $smokeArguments
if ($LASTEXITCODE -ne 0) { throw 'MindSpore W8 cached decoder loop failed.' }
$mindSporeLine = @($mindSporeOutput | Where-Object { $_ -like 'TOKENS *' })[-1]
if (-not $mindSporeLine) { throw 'MindSpore smoke did not report tokens.' }
$mindSporeTokens = @($mindSporeLine.Substring(7).Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { [int]$_ })

$onnxArguments = @((Join-Path $PSScriptRoot 'export_marian_smoke.py'), '--checkpoint', $OnnxDir, '--output-root', $OnnxDir, '--contract', $Contract, '--profile', $Profile, '--cache-loop-only')
if ($EvidenceFixtureRoot) { $onnxArguments += @('--binary-fixture-root', $EvidenceFixtureRoot) }
$onnxJson = & $Python $onnxArguments
if ($LASTEXITCODE -ne 0) { throw 'ONNX cached decoder loop failed.' }
$onnxTokens = @((($onnxJson | Select-Object -Last 1) | ConvertFrom-Json).tokens | ForEach-Object { [int]$_ })
if (($mindSporeTokens -join ',') -ne ($onnxTokens -join ',')) {
  throw "W8 argmax divergence: MindSpore=$($mindSporeTokens -join ',') ONNX=$($onnxTokens -join ',')"
}
if ($Profile -eq 'prototype') {
  $expectedPrototypeTokens = @(422, 21, 23, 22, 80, 5)
  if (($mindSporeTokens -join ',') -ne ($expectedPrototypeTokens -join ',')) {
    throw "prototype cache fixture drift: expected=$($expectedPrototypeTokens -join ',') actual=$($mindSporeTokens -join ',')"
  }
}

$models = foreach ($name in @('encoder', 'decoder_prefill', 'decoder_step')) {
  $path = Join-Path $w8Dir "$name.ms"
  [ordered]@{ name = "$name.ms"; size = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
}
$report = [ordered]@{
  profile = $Profile
  quantization = [ordered]@{ type = 'WEIGHT_QUANT'; bitNum = 8; minWeightSize = 0; minWeightChannel = 0 }
  cacheLoopTokens = $mindSporeTokens
  expectedCacheLoopTokens = if ($Profile -eq 'prototype') { @(422, 21, 23, 22, 80, 5) } else { $null }
  argmaxAgreement = 1.0
  models = $models
}
[IO.File]::WriteAllText((Join-Path $resolvedOutput 'conversion-report.json'), (($report | ConvertTo-Json -Depth 8) + "`n"), (New-Object Text.UTF8Encoding($false)))
$report | ConvertTo-Json -Depth 8
