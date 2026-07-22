$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $PSScriptRoot
$guard = Join-Path $PSScriptRoot 'check-gesture-fixtures.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $tempParent ("gesture-fixture-guard-" + [Guid]::NewGuid().ToString('N'))
$relativeRoot = 'entry\src\ohosTest\resources\rawfile\fixtures\gesture'

function Reset-Fixture {
  $target = Join-Path $fixtureRoot $relativeRoot
  if ([IO.Directory]::Exists($target)) { [IO.Directory]::Delete($target, $true) }
  [IO.Directory]::CreateDirectory($target) | Out-Null
  foreach ($name in @('four.jpg', 'solid_gray.png', 'NOTICE.md')) {
    [IO.File]::Copy((Join-Path $sourceRoot "$relativeRoot\$name"), (Join-Path $target $name), $true)
  }
}

function Assert-Rejected([string]$name, [scriptblock]$mutate) {
  Reset-Fixture
  & $mutate
  $rejected = $false
  try { & $guard -SourceRoot $fixtureRoot *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Gesture fixture guard accepted mutation: $name" }
  Write-Output "Rejected gesture fixture mutation: $name"
}

try {
  Reset-Fixture
  & $guard -SourceRoot $fixtureRoot *> $null
  Assert-Rejected 'changed positive bytes' {
    $path = Join-Path $fixtureRoot "$relativeRoot\four.jpg"
    $bytes = [IO.File]::ReadAllBytes($path)
    $bytes[100] = $bytes[100] -bxor 1
    [IO.File]::WriteAllBytes($path, $bytes)
  }
  Assert-Rejected 'missing pinned license statement' {
    $path = Join-Path $fixtureRoot "$relativeRoot\NOTICE.md"
    $text = [IO.File]::ReadAllText($path).Replace('License: Apache License 2.0', 'License: unknown')
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
  }
  Assert-Rejected 'obsolete unlicensed fixture restored' {
    [IO.File]::WriteAllBytes((Join-Path $fixtureRoot "$relativeRoot\open_palm.png"), [byte[]]@(1))
  }
  Write-Output 'Gesture fixture guard mutation tests passed.'
} finally {
  $resolved = [IO.Path]::GetFullPath($fixtureRoot)
  if ($resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($resolved)) {
    [IO.Directory]::Delete($resolved, $true)
  }
}
