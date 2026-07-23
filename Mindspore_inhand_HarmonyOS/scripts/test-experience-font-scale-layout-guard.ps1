$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guardRelativePath = 'scripts\check-experience-font-scale-layout.ps1'
$sourceRelativePaths = @(
  'entry\src\main\ets\common\components\ExperienceHeader.ets',
  'entry\src\main\ets\pages\ExperiencePage.ets',
  'entry\src\main\ets\common\components\BottomTabBar.ets'
)
$script:failures = [Collections.Generic.List[string]]::new()

function New-FixtureRoot {
  $root = Join-Path ([IO.Path]::GetTempPath()) (
    'experience-font-scale-guard-' + [Guid]::NewGuid().ToString('N')
  )
  foreach ($relativePath in @($guardRelativePath) + $sourceRelativePaths) {
    $destination = Join-Path $root $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relativePath) -Destination $destination
  }
  return [IO.Path]::GetFullPath($root)
}

function Remove-FixtureRoot([string]$Root) {
  $resolvedRoot = [IO.Path]::GetFullPath($Root)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $leaf = Split-Path -Leaf $resolvedRoot
  if (-not $resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      $leaf -notlike 'experience-font-scale-guard-*') {
    throw "Experience font-scale guard fixture refused unsafe cleanup: $resolvedRoot"
  }
  Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}

function Invoke-Guard([string]$FixtureRoot) {
  $guardPath = Join-Path $FixtureRoot $guardRelativePath
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guardPath 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  return @{
    ExitCode = $exitCode
    Output = $output.Trim()
  }
}

function Replace-First(
  [string]$Source,
  [string]$Before,
  [string]$After,
  [string]$Description
) {
  $index = $Source.IndexOf($Before, [StringComparison]::Ordinal)
  if ($index -lt 0) {
    throw "Experience font-scale guard fixture could not find mutation target: $Description"
  }
  return $Source.Substring(0, $index) + $After + $Source.Substring($index + $Before.Length)
}

function Test-Mutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$Before,
  [string]$After,
  [bool]$ShouldPass
) {
  $fixtureRoot = New-FixtureRoot
  try {
    $path = Join-Path $fixtureRoot $RelativePath
    $source = Get-Content -LiteralPath $path -Raw
    $mutated = Replace-First $source $Before $After $Name
    Set-Content -LiteralPath $path -Value $mutated -Encoding UTF8 -NoNewline
    $result = Invoke-Guard $fixtureRoot
    if ($ShouldPass -and $result.ExitCode -ne 0) {
      $script:failures.Add(
        "false positive '$Name': guard exit=$($result.ExitCode); output=$($result.Output)"
      )
    } elseif (-not $ShouldPass -and $result.ExitCode -eq 0) {
      $script:failures.Add("false negative '$Name': guard accepted unsafe mutation")
    } else {
      $expectation = if ($ShouldPass) { 'accepted' } else { 'rejected' }
      Write-Output "PASS $expectation mutation: $Name"
    }
  } finally {
    Remove-FixtureRoot $fixtureRoot
  }
}

$baselineRoot = New-FixtureRoot
try {
  $baseline = Invoke-Guard $baselineRoot
  if ($baseline.ExitCode -ne 0) {
    throw "Experience font-scale guard fixture rejected the valid baseline: $($baseline.Output)"
  }
  Write-Output 'PASS accepted valid baseline'
} finally {
  Remove-FixtureRoot $baselineRoot
}

$headerPath = 'entry\src\main\ets\common\components\ExperienceHeader.ets'
$pagePath = 'entry\src\main\ets\pages\ExperiencePage.ets'
$bottomTabPath = 'entry\src\main\ets\common\components\BottomTabBar.ets'

Test-Mutation 'hero content owner maxHeight' $headerPath `
  '.constraintSize({ minHeight: experienceHeaderMinHeightVp })' `
  ".constraintSize({ minHeight: experienceHeaderMinHeightVp })`n      .constraintSize({ maxHeight: 200 })" `
  $false
Test-Mutation 'groupTitle arbitrary fixed height' $pagePath `
  '.constraintSize({ minHeight: experienceGroupTitleMinHeightVp })' `
  ".constraintSize({ minHeight: experienceGroupTitleMinHeightVp })`n    .height(31)" `
  $false
Test-Mutation 'sectionTitle named fixed height' $pagePath `
  '.constraintSize({ minHeight: experienceSectionTitleMinHeightVp })' `
  ".constraintSize({ minHeight: experienceSectionTitleMinHeightVp })`n    .height(experienceSectionTitleMinHeightVp)" `
  $false
Test-Mutation 'sticky title arbitrary fixed height' $pagePath `
  '.constraintSize({ minHeight: experienceStickyTitleMinHeightVp })' `
  ".constraintSize({ minHeight: experienceStickyTitleMinHeightVp })`n    .height(31)" `
  $false
Test-Mutation 'bottom-tab item named fixed height' $bottomTabPath `
  '.constraintSize({ minHeight: bottomTabItemMinHeightVp })' `
  ".constraintSize({ minHeight: bottomTabItemMinHeightVp })`n        .height(bottomTabItemMinHeightVp)" `
  $false
Test-Mutation 'floating bottom bar maxHeight' $bottomTabPath `
  '.constraintSize({ minHeight: bottomTabBarMinHeightVp })' `
  ".constraintSize({ minHeight: bottomTabBarMinHeightVp })`n    .constraintSize({ maxHeight: 80 })" `
  $false
Test-Mutation 'target bottom-tab label fixed lines' $bottomTabPath `
  '.fontSize(11)' `
  ".fontSize(11)`n            .maxLines(2)" `
  $false

$unrelatedBuilder = @'
  @Builder
  private unrelatedDiagnosticLabel() {
    Text('diagnostic')
      .maxLines(1)
  }

  build() {
'@
Test-Mutation 'unrelated builder fixed lines' $pagePath `
  '  build() {' `
  $unrelatedBuilder `
  $true
Test-Mutation 'decorative section accent height' $pagePath `
  '.height(16)' `
  '.height(20)' `
  $true

if ($script:failures.Count -gt 0) {
  throw "Experience font-scale guard self-test failed:`n- $($script:failures -join "`n- ")"
}

Write-Output 'Experience font-scale layout guard mutation fixtures passed.'
