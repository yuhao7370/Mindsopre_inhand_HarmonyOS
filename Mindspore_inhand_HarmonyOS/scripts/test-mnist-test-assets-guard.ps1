[CmdletBinding()]
param(
  [string]$SourceRoot = (Join-Path $PSScriptRoot '..'),
  [string]$PythonExe = 'python',
  [switch]$SkipMutation
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$assetRoot = Join-Path $SourceRoot 'test-assets\handwritten-digits'
$readmePath = Join-Path $assetRoot 'README.md'
$validatorPath = Join-Path $SourceRoot 'scripts\validate-mnist-test-assets.py'
$expectedFiles = @('digit-2.png', 'digit-7.png', 'digit-9.png')

function Read-Manifest([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing digit fixture manifest: $Path" }
  $readme = [IO.File]::ReadAllText($Path)
  $match = [regex]::Match($readme, '(?s)<!-- mnist-test-assets-manifest\s*(?<json>\[.*?\])\s*-->')
  if (-not $match.Success) { throw 'README.md is missing the mnist-test-assets manifest.' }
  return @($match.Groups['json'].Value | ConvertFrom-Json)
}

function Test-Assets([string]$Root) {
  if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) { throw "Missing validator: $validatorPath" }
  foreach ($file in $expectedFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $assetRoot $file) -PathType Leaf)) { throw "Missing digit fixture: $file" }
  }
  $manifest = Read-Manifest $readmePath
  if ($manifest.Count -ne 3) { throw "Manifest must describe exactly three fixtures, got $($manifest.Count)." }
  $manifestFiles = @($manifest | ForEach-Object { [string]$_.file })
  $sortedManifestFiles = @($manifestFiles | Sort-Object)
  $sortedExpectedFiles = @($expectedFiles | Sort-Object)
  if ($manifestFiles.Count -ne $expectedFiles.Count -or
    $manifestFiles.Count -ne @($manifestFiles | Sort-Object -Unique).Count -or
    ($sortedManifestFiles -join '|') -cne ($sortedExpectedFiles -join '|')) {
    throw 'Manifest files must uniquely and completely cover digit-2.png, digit-7.png, and digit-9.png.'
  }
  $fixtureHashes = @{}
  foreach ($file in $expectedFiles) {
    $record = @($manifest | Where-Object { [string]$_.file -ceq $file })
    if ($record.Count -ne 1) { throw "Manifest must contain exactly one record for $file." }
    $record = $record[0]
    $expectedDigit = [int]($file -replace '^digit-(\d)\.png$', '$1')
    if ([int]$record.expected -ne $expectedDigit) { throw "Manifest label mismatch for $($record.file)." }
    if ([string]::IsNullOrWhiteSpace([string]$record.prompt) -or [string]::IsNullOrWhiteSpace([string]$record.source)) {
      throw "Manifest source or prompt is missing for $($record.file)."
    }
    $path = Join-Path $assetRoot $file
    $image = [System.Drawing.Image]::FromFile($path)
    try { $dimensions = "$($image.Width)x$($image.Height)" } finally { $image.Dispose() }
    if ([string]$record.dimensions -cne $dimensions) { throw "Manifest dimensions mismatch for $($record.file): $dimensions" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ([string]$record.sha256 -cne $hash) { throw "Manifest SHA-256 mismatch for $($record.file)." }
    $fixtureHashes[$hash] = $file
  }
  $entryRoot = Join-Path $Root 'entry'
  if (Test-Path -LiteralPath $entryRoot -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $entryRoot -Recurse -File) {
      if ($fixtureHashes.ContainsKey((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)) {
        throw "Digit fixture leaked into HAP source path: $($file.FullName)"
      }
    }
  }
  & $PythonExe $validatorPath --root $Root --self-test
  if ($LASTEXITCODE -ne 0) { throw 'MNIST fixture preprocessor self-test failed.' }
  $json = & $PythonExe $validatorPath --root $Root --json
  if ($LASTEXITCODE -ne 0) { throw 'MNIST fixture validator failed.' }
  $results = $json | ConvertFrom-Json
  if ($results.Count -ne 3) { throw "Validator must return three results, got $($results.Count)." }
  foreach ($record in $manifest) {
    $result = @($results | Where-Object { $_.file -ceq $record.file })
    if ($result.Count -ne 1) { throw "Validator result missing for $($record.file)." }
    if ([int]$result[0].predicted -ne [int]$record.expected) { throw "Wrong prediction for $($record.file): $($result[0].predicted)" }
    if ([int]$record.predicted -ne [int]$result[0].predicted -or
      [Math]::Abs([double]$record.confidence - [double]$result[0].confidence) -gt 0.000001) {
      throw "Manifest validation result drift for $($record.file)."
    }
  }
}

Test-Assets $SourceRoot

if (-not $SkipMutation) {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mih-mnist-assets-' + [Guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'docs\tutorials') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'docs\tutorials\college-hap') -Destination (Join-Path $tempRoot 'docs\tutorials\college-hap') -Recurse
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'test-assets') -Force | Out-Null
    Copy-Item -LiteralPath $assetRoot -Destination (Join-Path $tempRoot 'test-assets\handwritten-digits') -Recurse
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') | Out-Null
    Copy-Item -LiteralPath $validatorPath -Destination (Join-Path $tempRoot 'scripts\validate-mnist-test-assets.py')
    $fixtureReadme = Join-Path $tempRoot 'test-assets\handwritten-digits\README.md'
    $originalReadme = [IO.File]::ReadAllText($fixtureReadme)
    [IO.File]::WriteAllText($fixtureReadme, $originalReadme.Replace('"expected": 2', '"expected": 1'))
    $rejected = $false
    try { & $PSCommandPath -SourceRoot $tempRoot -PythonExe $PythonExe -SkipMutation *> $null } catch { $rejected = $true }
    if (-not $rejected) { throw 'MNIST asset guard accepted a manifest label mutation.' }
    $manifestMatch = [regex]::Match($originalReadme, '(?s)<!-- mnist-test-assets-manifest\s*(?<json>\[.*?\])\s*-->')
    $records = $manifestMatch.Groups['json'].Value | ConvertFrom-Json
    $duplicates = ConvertTo-Json -InputObject ([object[]]@($records[0], $records[0], $records[0])) -Depth 8
    [IO.File]::WriteAllText($fixtureReadme, $originalReadme.Substring(0, $manifestMatch.Groups['json'].Index) +
      $duplicates + $originalReadme.Substring($manifestMatch.Groups['json'].Index + $manifestMatch.Groups['json'].Length))
    $rejected = $false
    try { & $PSCommandPath -SourceRoot $tempRoot -PythonExe $PythonExe -SkipMutation *> $null } catch { $rejected = $true }
    if (-not $rejected) { throw 'MNIST asset guard accepted duplicate manifest files.' }
  } finally {
    if ([IO.Directory]::Exists($tempRoot)) { [IO.Directory]::Delete($tempRoot, $true) }
  }
}

Write-Output 'MNIST handwritten digit fixture guard passed.'
