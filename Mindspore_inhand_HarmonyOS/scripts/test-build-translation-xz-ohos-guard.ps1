[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$builder = Join-Path $projectRoot 'scripts\build-translation-xz-ohos.ps1'
$legacyBuilder = Join-Path $projectRoot '..\tools\translation\build_xz_ohos.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
  throw "Missing translation XZ builder: $builder"
}
if (-not (Test-Path -LiteralPath $legacyBuilder -PathType Leaf)) { throw "Missing legacy XZ builder: $legacyBuilder" }
$legacyText = Get-Content -LiteralPath $legacyBuilder -Raw
if ($legacyText -cnotmatch 'build-translation-xz-ohos\.ps1' -or $legacyText -cmatch 'ConvertTo-Json') {
  throw 'Legacy XZ builder must be a thin forwarder to the project builder.'
}

$testRoot = Join-Path $env:TEMP ("mindspore-inhand-xz-guard-" + [guid]::NewGuid().ToString('N'))
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Guard([string]$Project, [string]$Abi) {
  $script = Join-Path $Project 'scripts\build-translation-xz-ohos.ps1'
  $cache = Join-Path $testRoot 'verify-only-cache-must-not-exist'
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $script `
      -Abi $Abi -CacheRoot $cache -VerifyOnly 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Output = $output.Trim(); CacheExists = Test-Path -LiteralPath $cache }
}

function New-Fixture([string]$Name) {
  $fixture = Join-Path $testRoot "$Name\Mindspore_inhand_HarmonyOS"
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\libs')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main\cpp\translation_xz')) | Out-Null
  Copy-Item -LiteralPath $builder -Destination (Join-Path $fixture 'scripts\build-translation-xz-ohos.ps1')
  Copy-Item -LiteralPath (Join-Path $projectRoot 'entry\libs\arm64-v8a') -Destination (Join-Path $fixture 'entry\libs\arm64-v8a') -Recurse
  Copy-Item -LiteralPath (Join-Path $projectRoot 'entry\libs\x86_64') -Destination (Join-Path $fixture 'entry\libs\x86_64') -Recurse
  Copy-Item -Path (Join-Path $projectRoot 'entry\src\main\cpp\translation_xz\*') `
    -Destination (Join-Path $fixture 'entry\src\main\cpp\translation_xz') -Recurse
  return $fixture
}

function Expect-Rejected([string]$Name, [string]$Abi, [scriptblock]$Mutate) {
  $fixture = New-Fixture $Name
  & $Mutate $fixture
  $result = Invoke-Guard $fixture $Abi
  if ($result.ExitCode -eq 0) {
    $failures.Add("$Name was accepted")
  } else {
    Write-Output "PASS rejected $Name"
  }
}

try {
  [IO.Directory]::CreateDirectory($testRoot) | Out-Null
  foreach ($abi in @('arm64-v8a', 'x86_64')) {
    $fixture = New-Fixture "valid-$abi"
    $manifestName = if ($abi -ceq 'arm64-v8a') { 'XZ_BUILD_MANIFEST.json' } else { "XZ_BUILD_MANIFEST.$abi.json" }
    $manifestPath = Join-Path $fixture "entry\src\main\cpp\translation_xz\$manifestName"
    $before = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    $result = Invoke-Guard $fixture $abi
    if ($result.ExitCode -ne 0) { $failures.Add("valid $abi failed: $($result.Output)") }
    if ($result.CacheExists) { $failures.Add("VerifyOnly created cache for $abi") }
    if ((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -cne $before) {
      $failures.Add("VerifyOnly rewrote manifest for $abi")
    }
    & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $legacyBuilder -Abi $abi -VerifyOnly *> $null
    if ($LASTEXITCODE -ne 0) { $failures.Add("legacy forwarder failed VerifyOnly for $abi") }
  }

  Expect-Rejected 'tampered-x86-wrapper' 'x86_64' {
    param($fixture)
    $path = Join-Path $fixture 'entry\libs\x86_64\libtranslation_archive.so'
    $bytes = [IO.File]::ReadAllBytes($path)
    $bytes[0] = $bytes[0] -bxor 1
    [IO.File]::WriteAllBytes($path, $bytes)
  }
  Expect-Rejected 'wrong-x86-manifest-abi' 'x86_64' {
    param($fixture)
    $path = Join-Path $fixture 'entry\src\main\cpp\translation_xz\XZ_BUILD_MANIFEST.x86_64.json'
    $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $json.toolchain.abi = 'arm64-v8a'
    [IO.File]::WriteAllText($path, (($json | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
  }

  if ($failures.Count -ne 0) { throw "Translation XZ guard failures:`n- $($failures -join "`n- ")" }
  Write-Output 'Translation XZ builder guard passed.'
} finally {
  $prefix = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\mindspore-inhand-xz-guard-'
  $resolved = [IO.Path]::GetFullPath($testRoot)
  if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
