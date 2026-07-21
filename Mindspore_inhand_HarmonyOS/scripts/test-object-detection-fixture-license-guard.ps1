$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $PSScriptRoot
$guardPath = Join-Path $PSScriptRoot 'check-object-detection-fixture-license.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $tempParent ("object-detection-license-guard-" + [guid]::NewGuid().ToString('N'))
$relativeNotice = 'entry\src\ohosTest\resources\rawfile\fixtures\classification\NOTICE.md'
$relativeImage = 'entry\src\ohosTest\resources\rawfile\fixtures\classification\yellow_labrador.jpg'
$utf8 = [Text.UTF8Encoding]::new($false)

function Copy-GuardSources {
  foreach ($relativePath in @($relativeNotice, $relativeImage)) {
    $targetPath = Join-Path $fixtureRoot $relativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $targetPath)) | Out-Null
    [IO.File]::Copy((Join-Path $sourceRoot $relativePath), $targetPath, $true)
  }
}

function Assert-RejectsNoticeMutation([string]$Name, [string]$OldText, [string]$NewText) {
  Copy-GuardSources
  $noticePath = Join-Path $fixtureRoot $relativeNotice
  $notice = [IO.File]::ReadAllText($noticePath)
  $first = $notice.IndexOf($OldText, [StringComparison]::Ordinal)
  $last = $notice.LastIndexOf($OldText, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $first -ne $last) {
    throw "Fixture mutation must match exactly once: $Name"
  }
  [IO.File]::WriteAllText($noticePath, $notice.Substring(0, $first) + $NewText +
    $notice.Substring($first + $OldText.Length), $utf8)
  $rejected = $false
  try {
    & $guardPath -SourceRoot $fixtureRoot *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Object-detection fixture license guard accepted mutation: $Name"
  }
  Write-Output "Rejected fixture license mutation: $Name"
}

try {
  Copy-GuardSources
  & $guardPath -SourceRoot $fixtureRoot *> $null
  Assert-RejectsNoticeMutation 'ambiguous dual-license selection' `
    'Selected redistribution license: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0).' `
    'Available licenses include CC BY-SA 3.0 and GFDL.'
  Assert-RejectsNoticeMutation 'missing canonical license URI' `
    'License URI: https://creativecommons.org/licenses/by-sa/3.0/' `
    'License URI: omitted'
  Assert-RejectsNoticeMutation 'missing author and retouch attribution' `
    'Original photograph by Elf; derivative work by Djmirko; retouched by FT2.' `
    'Wikimedia Commons contributors.'
  Assert-RejectsNoticeMutation 'missing modification disclosure' `
    'Project changes to the image bytes: none; this is the unchanged 700x577 Wikimedia Commons file.' `
    'Project modification status: unspecified.'
  Assert-RejectsNoticeMutation 'annotation confused with image modification' `
    'The project-authored detection box is separate test metadata and is not embedded in the image.' `
    'The project-authored detection box is part of the fixture.'
  Write-Output 'Object-detection fixture license guard mutation fixtures passed.'
} finally {
  $resolvedFixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
  if ($resolvedFixtureRoot.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($resolvedFixtureRoot)) {
    [IO.Directory]::Delete($resolvedFixtureRoot, $true)
  }
}
