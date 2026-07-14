$ErrorActionPreference = 'Stop'

$guard = Join-Path $PSScriptRoot 'check-feature-runtime-view-ids.ps1'
$powershell = (Get-Process -Id $PID).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("feature-runtime-view-ids-" + [Guid]::NewGuid().ToString('N'))
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$utf8 = New-Object Text.UTF8Encoding($false)

if (-not $tempRoot.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe test fixture path: $tempRoot"
}

function New-PageFixture(
  [string]$Name,
  [string]$CompositeBody,
  [string]$GenericBody,
  [string]$PoseBody,
  [string]$LineEnding = "`n"
) {
  $path = Join-Path $tempRoot "$Name.ets"
  $source = @"
portraitSegmentationComposite() {
$CompositeBody
}

portraitSegmentationBackgroundStrip() {
}

segmentationBackgroundReplacementPreview(pixelMap: image.PixelMap) {
$GenericBody
}

segmentationBox(rectangle: SegmentationRectangle) {
}

posePreview(labelKey: AppStringKey, uri: string) {
$PoseBody
}

poseTemplatePreview() {
}
"@
  $source = $source.Replace("`r`n", "`n").Replace("`r", "`n")
  if ($LineEnding -eq "`r`n") {
    $source = $source.Replace("`n", "`r`n")
  }
  [IO.File]::WriteAllText($path, $source, $utf8)
  return $path
}

function Invoke-Guard([string]$PagePath) {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
      -File $guard -PagePath $PagePath 2>&1
    return [PSCustomObject]@{
      ExitCode = $LASTEXITCODE
      Output = ($output | Out-String)
    }
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Assert-GuardAccepts([string]$Label, [string]$PagePath) {
  $result = Invoke-Guard $PagePath
  if ($result.ExitCode -ne 0) {
    throw "Guard rejected valid fixture '$Label':`n$($result.Output)"
  }
  Write-Output "PASS accept: $Label"
}

function Assert-GuardRejects([string]$Label, [string]$PagePath, [string]$ExpectedMessage) {
  $result = Invoke-Guard $PagePath
  if ($result.ExitCode -eq 0) {
    throw "Guard unexpectedly accepted invalid fixture: $Label"
  }
  if (-not $result.Output.Contains($ExpectedMessage)) {
    throw "Guard rejected '$Label' for the wrong reason:`n$($result.Output)"
  }
  Write-Output "PASS reject: $Label"
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  $goodCompositeBody = @'
  Stack() {
    Image()
  }
  .width('100%')
  .id(segmentationBackgroundReplacementComponentId)
'@
  $goodLf = New-PageFixture 'good-lf' $goodCompositeBody '' '' "`n"
  $goodCrLf = New-PageFixture 'good-crlf' $goodCompositeBody '' '' "`r`n"
  $nestedChild = New-PageFixture 'nested-child' @'
  Stack() {
    Image()
      .id(segmentationBackgroundReplacementComponentId)
  }
  .width('100%')
'@ '' ''
  $commentAndString = New-PageFixture 'comment-string' @'
  Stack() {
    Text('.id(segmentationBackgroundReplacementComponentId)')
    // .id(segmentationBackgroundReplacementComponentId)
  }
  .width('100%')
  .id(segmentationBackgroundReplacementComponentId)
'@ '' ''
  $oldGeneric = New-PageFixture 'old-generic' @'
  Stack() {
  }
  .width('100%')
'@ @'
  Stack() {
  }
  .id(segmentationBackgroundReplacementComponentId)
'@ ''
  $duplicate = New-PageFixture 'duplicate' @'
  Stack() {
    Image()
      .id(segmentationBackgroundReplacementComponentId)
  }
  .id(segmentationBackgroundReplacementComponentId)
'@ '' ''
  $pose = New-PageFixture 'pose' @'
  Stack() {
  }
  .width('100%')
'@ '' @'
  Stack() {
  }
  .id(segmentationBackgroundReplacementComponentId)
'@
  $missing = New-PageFixture 'missing' @'
  Stack() {
  }
  .width('100%')
'@ '' ''

  Assert-GuardAccepts 'portrait composite with LF' $goodLf
  Assert-GuardAccepts 'portrait composite with CRLF' $goodCrLf
  Assert-GuardRejects 'nested child component' $nestedChild `
    'must be attached directly to the outer portrait Stack'
  Assert-GuardAccepts 'comment and string lookalikes' $commentAndString
  Assert-GuardRejects 'old generic preview' $oldGeneric `
    'must not be attached to segmentationBackgroundReplacement'
  Assert-GuardRejects 'duplicate id binding' $duplicate `
    'found 2.'
  Assert-GuardRejects 'pose preview' $pose `
    'must not be attached to posePreview'
  Assert-GuardRejects 'missing id binding' $missing `
    'found 0.'

  Write-Output 'Feature runtime view id guard fixture tests passed.'
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
