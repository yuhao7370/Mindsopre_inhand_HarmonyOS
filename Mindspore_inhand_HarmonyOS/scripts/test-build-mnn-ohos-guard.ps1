[CmdletBinding()]
param([switch]$SkipFreshClone)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '..'))
$testRoot = Join-Path $env:TEMP ("mindspore-inhand-mnn-guard-tests-" + [guid]::NewGuid().ToString('N'))
$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-Guard([string]$Project) {
  $script = Join-Path $Project 'scripts\build-mnn-ohos.ps1'
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $script -VerifyOnly 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Output = $output.Trim() }
}

function New-Fixture([string]$Name) {
  $fixture = Join-Path $testRoot "$Name\Mindspore_inhand_HarmonyOS"
  [System.IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts')) | Out-Null
  [System.IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\libs\arm64-v8a')) | Out-Null
  [System.IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main')) | Out-Null
  Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts\build-mnn-ohos.ps1') -Destination (Join-Path $fixture 'scripts\build-mnn-ohos.ps1')
  Copy-Item -LiteralPath (Join-Path $projectRoot 'entry\libs\arm64-v8a\libMNN.so') -Destination (Join-Path $fixture 'entry\libs\arm64-v8a\libMNN.so')
  Copy-Item -LiteralPath (Join-Path $projectRoot 'entry\src\main\cpp') -Destination (Join-Path $fixture 'entry\src\main\cpp') -Recurse
  return $fixture
}

function Read-Manifest([string]$Project) {
  return Get-Content -LiteralPath (Join-Path $Project 'entry\src\main\cpp\MNN_BUILD_MANIFEST.json') -Raw | ConvertFrom-Json
}

function Write-Manifest([string]$Project, [object]$Manifest) {
  $path = Join-Path $Project 'entry\src\main\cpp\MNN_BUILD_MANIFEST.json'
  [System.IO.File]::WriteAllText($path, (($Manifest | ConvertTo-Json -Depth 8) + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Expect-Rejected([string]$Name, [scriptblock]$Mutate) {
  $fixture = New-Fixture $Name
  & $Mutate $fixture
  $result = Invoke-Guard $fixture
  if ($result.ExitCode -eq 0) {
    $failures.Add("$Name was accepted: $($result.Output)")
  } else {
    Write-Output "PASS rejected $Name"
  }
}

try {
  [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

  if (-not $SkipFreshClone) {
    $clone = Join-Path $testRoot 'fresh-clone'
    & git clone --quiet --no-local $repositoryRoot $clone
    if ($LASTEXITCODE -ne 0) { throw 'Fresh local clone failed.' }
    $head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    & git -C $clone checkout --quiet --detach $head
    if ($LASTEXITCODE -ne 0) { throw "Cannot check out $head in fresh clone." }
    $cloneResult = Invoke-Guard (Join-Path $clone 'Mindspore_inhand_HarmonyOS')
    if ($cloneResult.ExitCode -ne 0) {
      $failures.Add("fresh clone failed VerifyOnly: $($cloneResult.Output)")
    } else {
      Write-Output 'PASS fresh clone VerifyOnly'
    }
  }

  Expect-Rejected 'forged-nonreference' {
    param($fixture)
    $library = Join-Path $fixture 'entry\libs\arm64-v8a\libMNN.so'
    $bytes = [System.IO.File]::ReadAllBytes($library)
    [Array]::Resize([ref]$bytes, $bytes.Length + 1)
    $bytes[$bytes.Length - 1] = 0
    [System.IO.File]::WriteAllBytes($library, $bytes)
    $manifest = Read-Manifest $fixture
    $manifest.artifact.size = $bytes.Length
    $manifest.artifact.sha256 = (Get-FileHash -LiteralPath $library -Algorithm SHA256).Hash
    $manifest.toolchainInputDifference = 'FORGED: no actual toolchain input differs'
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'extra-header-entry' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.headers += [pscustomobject]@{ path = 'include/MNN/Extra.hpp'; sha256 = ('0' * 64) }
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'missing-header-entry' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.headers = @($manifest.headers | Select-Object -Skip 1)
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'duplicate-header-entry' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.headers += $manifest.headers[0]
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'extra-header-property' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.headers[0] | Add-Member -NotePropertyName 'note' -NotePropertyValue 'unexpected'
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'wrong-header-field-type' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.headers[0].sha256 = 1
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'extra-build-flag' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.build.cmakeFlags | Add-Member -NotePropertyName 'MNN_FAKE_OPTION' -NotePropertyValue 'OFF'
    Write-Manifest $fixture $manifest
  }


  Expect-Rejected 'missing-build-flag' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.build.cmakeFlags.PSObject.Properties.Remove('MNN_OPENCL')
    Write-Manifest $fixture $manifest
  }

  Expect-Rejected 'duplicate-build-flag' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    Write-Manifest $fixture $manifest
    $path = Join-Path $fixture 'entry\src\main\cpp\MNN_BUILD_MANIFEST.json'
    $json = [System.IO.File]::ReadAllText($path)
    $pattern = [regex]::new('("MNN_OPENCL"\s*:\s*"OFF")')
    $json = $pattern.Replace($json, '$1,' + "`n" + '                                     "MNN_OPENCL": "OFF"', 1)
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
  }

  Expect-Rejected 'wrong-build-flag-type' {
    param($fixture)
    $manifest = Read-Manifest $fixture
    $manifest.build.cmakeFlags.MNN_OPENCL = $false
    Write-Manifest $fixture $manifest
  }

  if ($failures.Count -gt 0) {
    throw "MNN guard failures ($($failures.Count)):`n- $($failures -join "`n- ")"
  }
  Write-Output 'MNN guard negative suite passed.'
} finally {
  $safePrefix = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\mindspore-inhand-mnn-guard-tests-'
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  if ($resolvedTestRoot.StartsWith($safePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Test-Path -LiteralPath $resolvedTestRoot)) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
