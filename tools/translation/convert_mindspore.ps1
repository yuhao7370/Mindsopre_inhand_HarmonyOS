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
if ($resolvedOutput.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $resolvedOutput.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
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

$exportReport = $null
$exportReportArtifact = $null
if ($Profile -eq 'final') {
  & $Python (Join-Path $PSScriptRoot 'export_marian_smoke.py') --checkpoint $OnnxDir --output-root $OnnxDir --contract $Contract --profile $Profile --verify-export-report
  if ($LASTEXITCODE -ne 0) { throw 'Approved final ONNX export report verification failed.' }
  $exportReportPath = Join-Path $OnnxDir 'export-report.json'
  $exportReport = [IO.File]::ReadAllText($exportReportPath) | ConvertFrom-Json
  $exportReportArtifact = [ordered]@{
    path = 'export-report.json'
    bytes = (Get-Item -LiteralPath $exportReportPath).Length
    sha256 = (Get-FileHash -LiteralPath $exportReportPath -Algorithm SHA256).Hash.ToLowerInvariant()
  }
} else {
  & $Python (Join-Path $PSScriptRoot 'export_marian_smoke.py') --checkpoint $OnnxDir --output-root $OnnxDir --contract $Contract --profile $Profile --inspect-only
  if ($LASTEXITCODE -ne 0) { throw 'ONNX contract inspection failed.' }
}

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
$contractProfile = ([IO.File]::ReadAllText($Contract) | ConvertFrom-Json).profiles.$Profile
$maxTokens = [int]$contractProfile.maxTokens
$encoderParity = @()
foreach ($parityCase in @(
  [ordered]@{ name = 'all-valid'; validTokens = $maxTokens },
  [ordered]@{ name = 'half-padding'; validTokens = [int]($maxTokens / 2) }
)) {
  $mindSporeEncoderOutput = Join-Path $resolvedOutput ("encoder-{0}.float32.bin" -f $parityCase.name)
  $floatArguments = @(
    (Join-Path $floatDir 'encoder.ms'),
    (Join-Path $floatDir 'decoder_prefill.ms'),
    (Join-Path $floatDir 'decoder_step.ms'),
    '--steps=5',
    "--encoder-output=$mindSporeEncoderOutput",
    "--valid-tokens=$($parityCase.validTokens)"
  )
  $null = & $smokeExe $floatArguments
  if ($LASTEXITCODE -ne 0) { throw "MindSpore float parity run failed: $($parityCase.name)" }
  $parityJson = & $Python (Join-Path $PSScriptRoot 'export_marian_smoke.py') `
    --checkpoint $OnnxDir --output-root $OnnxDir --contract $Contract --profile $Profile `
    --encoder-mindspore-output $mindSporeEncoderOutput --encoder-valid-tokens $parityCase.validTokens
  if ($LASTEXITCODE -ne 0) { throw "ONNX/MindSpore float comparison failed: $($parityCase.name)" }
  $measured = ($parityJson | Select-Object -Last 1) | ConvertFrom-Json
  if ([double]$measured.maxAbs -gt 0.02 -or [double]$measured.meanAbs -gt 0.002) {
    throw "float parity exceeded bounds for $($parityCase.name): max=$($measured.maxAbs), mean=$($measured.meanAbs)"
  }
  $encoderParity += [ordered]@{
    name = $parityCase.name
    validTokens = [int]$measured.validTokens
    elements = [int]$measured.elements
    maxAbs = [double]$measured.maxAbs
    meanAbs = [double]$measured.meanAbs
  }
}

$requiredCacheSteps = if ($Profile -eq 'final') { 100 } else { 5 }
$smokeArguments = @((Join-Path $w8Dir 'encoder.ms'), (Join-Path $w8Dir 'decoder_prefill.ms'), (Join-Path $w8Dir 'decoder_step.ms'))
$smokeArguments += "--steps=$requiredCacheSteps"
if ($EvidenceFixtureRoot) { $smokeArguments += "--fixture-root=$EvidenceFixtureRoot" }
$mindSporeOutput = & $smokeExe $smokeArguments
if ($LASTEXITCODE -ne 0) { throw 'MindSpore W8 cached decoder loop failed.' }
$mindSporeLine = @($mindSporeOutput | Where-Object { $_ -like 'TOKENS *' })[-1]
if (-not $mindSporeLine) { throw 'MindSpore smoke did not report tokens.' }
$mindSporeTokens = @($mindSporeLine.Substring(7).Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { [int]$_ })

$onnxArguments = @((Join-Path $PSScriptRoot 'export_marian_smoke.py'), '--checkpoint', $OnnxDir, '--output-root', $OnnxDir, '--contract', $Contract, '--profile', $Profile, '--cache-loop-only', '--cache-loop-steps', $requiredCacheSteps)
if ($EvidenceFixtureRoot) { $onnxArguments += @('--binary-fixture-root', $EvidenceFixtureRoot) }
$onnxJson = & $Python $onnxArguments
if ($LASTEXITCODE -ne 0) { throw 'ONNX cached decoder loop failed.' }
$onnxTokens = @((($onnxJson | Select-Object -Last 1) | ConvertFrom-Json).tokens | ForEach-Object { [int]$_ })
if ($mindSporeTokens.Count -ne $onnxTokens.Count -or $mindSporeTokens.Count -ne ($requiredCacheSteps + 1)) {
  throw "W8 argmax token count differs: MindSpore=$($mindSporeTokens.Count) ONNX=$($onnxTokens.Count)"
}
$matchingTokens = 0
for ($index = 0; $index -lt $onnxTokens.Count; $index++) {
  if ($mindSporeTokens[$index] -eq $onnxTokens[$index]) { $matchingTokens++ }
}
$argmaxAgreement = $matchingTokens / [double]$onnxTokens.Count
if ($argmaxAgreement -lt 0.99) {
  throw "W8 argmax agreement below 99%: matches=$matchingTokens total=$($onnxTokens.Count) agreement=$argmaxAgreement"
}
if ($Profile -eq 'prototype') {
  $expectedPrototypeTokens = @(422, 22, 7, 4, 422, 22)
  if (($mindSporeTokens -join ',') -ne ($expectedPrototypeTokens -join ',')) {
    throw "prototype cache fixture drift: expected=$($expectedPrototypeTokens -join ',') actual=$($mindSporeTokens -join ',')"
  }
}

$models = foreach ($name in @('encoder', 'decoder_prefill', 'decoder_step')) {
  $path = Join-Path $w8Dir "$name.ms"
  [ordered]@{ name = "$name.ms"; size = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
}
$report = [ordered]@{
  schemaVersion = 1
  profile = $Profile
  approval = if ($exportReport) { $exportReport.approval } else { $null }
  exportReport = $exportReportArtifact
  onnxArtifacts = if ($exportReport) { $exportReport.onnxArtifacts } else { $null }
  quantization = [ordered]@{ type = 'WEIGHT_QUANT'; bitNum = 8; minWeightSize = 0; minWeightChannel = 0 }
  encoderParity = $encoderParity
  cacheLoopSteps = $requiredCacheSteps
  cacheLoopTokens = $mindSporeTokens
  referenceCacheLoopTokens = $onnxTokens
  expectedCacheLoopTokens = if ($Profile -eq 'prototype') { @(422, 22, 7, 4, 422, 22) } else { $null }
  argmaxAgreement = $argmaxAgreement
  matchingTokens = $matchingTokens
  models = $models
}
[IO.File]::WriteAllText((Join-Path $resolvedOutput 'conversion-report.json'), (($report | ConvertTo-Json -Depth 8) + "`n"), (New-Object Text.UTF8Encoding($false)))
$report | ConvertTo-Json -Depth 8
