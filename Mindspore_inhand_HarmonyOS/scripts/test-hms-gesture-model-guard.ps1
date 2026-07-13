$ErrorActionPreference = 'Stop'

$sourceAssets = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\gesture'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("hms-gesture-guard-test-" + [Guid]::NewGuid().ToString('N'))
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$fixtureScripts = Join-Path $tempRoot 'scripts'
$fixtureAssets = Join-Path $tempRoot 'entry\src\main\resources\rawfile\models\gesture'
$fixtureManifest = Join-Path $fixtureAssets 'manifest.json'
$fixtureVerifier = Join-Path $fixtureScripts 'verify-hms-gesture-model.ps1'
$powershell = (Get-Process -Id $PID).Path
$utf8 = New-Object Text.UTF8Encoding($false)

if (-not $tempRoot.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe test fixture path: $tempRoot"
}

function Invoke-FixtureGuard {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $fixtureVerifier *> $null
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Write-FixtureManifest($manifest) {
  $json = $manifest | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($fixtureManifest, $json, $utf8)
}

function Reset-FixtureManifest {
  Copy-Item -LiteralPath (Join-Path $sourceAssets 'manifest.json') -Destination $fixtureManifest -Force
}

function Assert-GuardRejects([string]$name, [scriptblock]$mutate) {
  Reset-FixtureManifest
  & $mutate
  if ((Invoke-FixtureGuard) -eq 0) {
    $script:acceptedInvalidCases += $name
  } else {
    Write-Output "PASS reject: $name"
  }
}

$acceptedInvalidCases = @()
New-Item -ItemType Directory -Path $fixtureScripts, $fixtureAssets | Out-Null
try {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'verify-hms-gesture-model.ps1') -Destination $fixtureVerifier
  Copy-Item -LiteralPath (Join-Path $sourceAssets 'GestureDetector.ms') -Destination $fixtureAssets
  Reset-FixtureManifest

  if ((Invoke-FixtureGuard) -ne 0) {
    throw 'The valid fixture did not pass the model guard.'
  }
  Write-Output 'PASS accept: valid manifest'

  Assert-GuardRejects 'missing explicit resultLimit' {
    $manifest = Get-Content -LiteralPath $fixtureManifest -Raw | ConvertFrom-Json
    $manifest.detector.PSObject.Properties.Remove('resultLimit')
    Write-FixtureManifest $manifest
  }

  Assert-GuardRejects 'numeric contract fields encoded as strings' {
    $manifest = Get-Content -LiteralPath $fixtureManifest -Raw | ConvertFrom-Json
    $manifest.schemaVersion = '1'
    $manifest.model.sizeBytes = '2269168'
    $manifest.input.normalization.divisor = '255'
    $manifest.detector.classCount = '15'
    $manifest.detector.valuesPerAnchor = '20'
    foreach ($head in $manifest.detector.heads) { $head.stride = [string]$head.stride }
    $manifest.detector.thresholds.still = '0.6'
    $manifest.detector.thresholds.live = '0.1'
    $manifest.detector.thresholds.nmsIou = '0.45'
    Write-FixtureManifest $manifest
  }

  Assert-GuardRejects 'tensor shapes and anchors encoded with wrong JSON types' {
    $manifest = Get-Content -LiteralPath $fixtureManifest -Raw | ConvertFrom-Json
    $manifest.input.shape = '1,3,224,224'
    $manifest.input.normalization.mean = '0,0,0'
    foreach ($output in $manifest.outputs) { $output.shape = $output.shape -join ',' }
    foreach ($head in $manifest.detector.heads) {
      $head.anchors = [object[]]@($head.anchors | ForEach-Object { $_ -join ',' })
    }
    Write-FixtureManifest $manifest
  }

  Assert-GuardRejects 'required string fields encoded as singleton arrays' {
    $manifest = Get-Content -LiteralPath $fixtureManifest -Raw | ConvertFrom-Json
    $manifest.format = [object[]]@('MNN FlatBuffer')
    $manifest.upstream.version = [object[]]@('2.1.0.300')
    $manifest.model.sha256 = [object[]]@('A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA')
    $manifest.input.name = [object[]]@('data')
    $manifest.outputs[0].name = [object[]]@('layer89-conv-hand')
    $manifest.detector.nms = [object[]]@('PER_CLASS')
    Write-FixtureManifest $manifest
  }

  Assert-GuardRejects 'duplicate required property' {
    $raw = Get-Content -LiteralPath $fixtureManifest -Raw
    $raw = $raw.Replace('"schemaVersion": 1,', '"schemaVersion": 1, "schemaVersion": 1,')
    [IO.File]::WriteAllText($fixtureManifest, $raw, $utf8)
  }

  if ($acceptedInvalidCases.Count -gt 0) {
    throw "Guard accepted invalid manifest case(s): $($acceptedInvalidCases -join '; ')"
  }
  Write-Output 'HMS gesture model guard negative tests passed.'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
