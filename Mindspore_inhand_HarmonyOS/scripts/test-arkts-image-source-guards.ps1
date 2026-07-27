$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-me-row-icons.ps1') | Out-Null
. (Join-Path $PSScriptRoot 'check-college-chevron-icon.ps1') | Out-Null

$script:passed = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-GuardAccepts(
  [string]$Name,
  [scriptblock]$GuardCall
) {
  try {
    & $GuardCall
  } catch {
    $script:failures.Add("Expected guard to accept '$Name', but it rejected the source: $($_.Exception.Message)")
    return
  }
  $script:passed++
}

function Assert-GuardRejects(
  [string]$Name,
  [scriptblock]$GuardCall
) {
  $rejected = $false
  try {
    & $GuardCall
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    $script:failures.Add("Expected guard to reject '$Name', but it accepted the source")
    return
  }
  $script:passed++
}

function New-MeFixture([string]$Body) {
  return @'
@Component
struct Fixture {
  @Builder
  private versionCard(item: MeItem) {
'@ + $Body + @'

  }
}
'@
}

$meValidLineStart = @'

    Image($r('app.media.me_version_v2'))
'@
$meValidInline = @'

    Row() { Image($r('app.media.me_version_v2')) }
'@

$meAcceptCases = [ordered]@{
  'Me approved version image at line start' = $meValidLineStart
  'Me approved version image inline' = $meValidInline
  'Me approved version image multiline' = @'

    Image(
      $r(
        'app.media.me_version_v2'
      )
    )
'@
  'Me ignores line-comment legacy decoys' = $meValidLineStart + @'

    // Image(iconMediaResource(item.icon))
    // Image(iconMediaResource('go'))
'@
  'Me ignores block-comment legacy decoys' = $meValidLineStart + @'

    /* Image(iconMediaResource(item.icon))
       Image(iconMediaResource("go")) */
'@
  'Me ignores ordinary-string legacy decoys' = $meValidLineStart + @'

    Text('Image(iconMediaResource(item.icon)) Image(iconMediaResource("go"))')
'@
  'Me ignores template-raw legacy decoys' = $meValidLineStart + @'

    Text(`Image(iconMediaResource(item.icon)) Image(iconMediaResource('go'))`)
'@
  'Me ignores prefixed FakeImage legacy item.icon call' = $meValidLineStart + @'

    FakeImage(iconMediaResource(item.icon))
'@
  'Me method slicing ignores comment and string braces' = $meValidLineStart + @'

    // }
    Text('}')
    /* { } */
'@
}

foreach ($case in $meAcceptCases.GetEnumerator()) {
  $source = New-MeFixture $case.Value
  Assert-GuardAccepts $case.Key { Assert-MeSourceContract $source }
}

$meRejectCases = [ordered]@{
  'Me rejects line-start item.icon' = $meValidLineStart + @'

    Image(iconMediaResource(item.icon))
'@
  'Me rejects inline item.icon' = $meValidLineStart + @'

    Row() { Image(iconMediaResource(item.icon)) }
'@
  'Me rejects multiline item.icon' = $meValidLineStart + @'

    Image(
      iconMediaResource(
        item.icon
      )
    )
'@
  'Me rejects line-start single-quoted go' = $meValidLineStart + @'

    Image(iconMediaResource('go'))
'@
  'Me rejects inline single-quoted go' = $meValidLineStart + @'

    Row() { Image(iconMediaResource('go')) }
'@
  'Me rejects multiline single-quoted go' = $meValidLineStart + @'

    Image(
      iconMediaResource(
        'go'
      )
    )
'@
  'Me rejects line-start double-quoted go' = $meValidLineStart + @'

    Image(iconMediaResource("go"))
'@
  'Me rejects inline double-quoted go' = $meValidLineStart + @'

    Row() { Image(iconMediaResource("go")) }
'@
  'Me rejects multiline double-quoted go' = $meValidLineStart + @'

    Image(
      iconMediaResource(
        "go"
      )
    )
'@
  'Me rejects missing approved version image' = @'

    Text('Version')
'@
  'Me rejects approved image only in line comment' = @'

    // Image($r('app.media.me_version_v2'))
'@
  'Me rejects approved image only in block comment' = @'

    /* Image($r('app.media.me_version_v2')) */
'@
  'Me rejects approved image only in ordinary string' = @'

    Text('Image($r(''app.media.me_version_v2''))')
'@
  'Me rejects approved image only in template raw text' = @'

    Text(`Image($r('app.media.me_version_v2'))`)
'@
  'Me rejects approved version resource only in prefixed FakeImage' = @'

    FakeImage($r('app.media.me_version_v2'))
'@
  'Me rejects approved image only in sibling method' = @'

    Text('Version')
  }

  @Builder
  private sibling() {
    Image($r('app.media.me_version_v2'))
'@
}

foreach ($case in $meRejectCases.GetEnumerator()) {
  $source = New-MeFixture $case.Value
  Assert-GuardRejects $case.Key { Assert-MeSourceContract $source }
}

$meFakeMethodSources = [ordered]@{
  'Me rejects block-comment fake versionCard method' = @'
/*
  private versionCard(item: MeItem) {
    Image($r('app.media.me_version_v2'))
  }
*/
'@
  'Me rejects template-raw fake versionCard method' = @'
const fake = `
  private versionCard(item: MeItem) {
    Image($r('app.media.me_version_v2'))
  }
`;
'@
}

foreach ($case in $meFakeMethodSources.GetEnumerator()) {
  $source = $case.Value
  Assert-GuardRejects $case.Key { Assert-MeSourceContract $source }
}

$meUnclosed = @'
@Component
struct Fixture {
  @Builder
  private versionCard(item: MeItem) {
    Image($r('app.media.me_version_v2'))
'@
Assert-GuardRejects 'Me rejects an unclosed versionCard method' {
  Assert-MeSourceContract $meUnclosed
}

function New-CollegeFixture(
  [string]$EntryBody,
  [string]$SiblingBody = ''
) {
  return @'
@Component
struct Fixture {
  @Builder
  private collegeEntryCard(item: CollegeItem) {
'@ + $EntryBody + @'

  }

  @Builder
  private sibling() {
'@ + $SiblingBody + @'

  }
}
'@
}

$collegeTitle = @'

    Text(appString(collegeAdapterViewTitleKey))
'@
$collegeValidLineStart = $collegeTitle + @'

    Image($r('app.media.me_go'))
      .width(6)
      .height(12)
'@
$collegeValidInline = $collegeTitle + @'

    Row() { Image($r('app.media.me_go')).width(6).height(12) }
'@

$collegeAcceptCases = [ordered]@{
  'College approved chevron at line start after title' = $collegeValidLineStart
  'College approved chevron inline after title' = $collegeValidInline
  'College approved chevron multiline after title' = $collegeTitle + @'

    Image(
      $r(
        'app.media.me_go'
      )
    )
      .width(
        6
      )
      .height(
        12
      )
'@
  'College ignores line-comment Text placeholder decoys' = $collegeValidLineStart + @'

    // Row() { Text('>') }
    // Row() { Text(">") }
'@
  'College ignores block-comment Text placeholder decoys' = $collegeValidLineStart + @'

    /* Row() { Text('>') }
       Row() { Text(">") } */
'@
  'College ignores ordinary-string Text placeholder decoys' = $collegeValidLineStart + @'

    Text('Documentation says Text(''>''), and Text(">") is obsolete')
'@
  'College ignores template-raw Text placeholder decoys' = $collegeValidLineStart + @'

    Text(`Row() { Text('>') } Row() { Text(">") }`)
'@
  'College ignores prefixed FakeText placeholder call' = $collegeValidLineStart + @'

    FakeText('>')
'@
  'College method slicing ignores comment and string braces' = $collegeValidLineStart + @'

    // }
    Text('}')
    /* { } */
'@
}

foreach ($case in $collegeAcceptCases.GetEnumerator()) {
  $source = New-CollegeFixture $case.Value
  Assert-GuardAccepts $case.Key { Assert-CollegeSourceContract $source }
}

$collegeRejectCases = [ordered]@{
  'College rejects wrong width' = $collegeTitle + @'

    Image($r('app.media.me_go')).width(5).height(12)
'@
  'College rejects wrong height' = $collegeTitle + @'

    Image($r('app.media.me_go')).width(6).height(11)
'@
  'College rejects chevron before title' = @'

    Image($r('app.media.me_go')).width(6).height(12)
    Text(appString(collegeAdapterViewTitleKey))
'@
  'College rejects borrowed size' = $collegeTitle + @'

    Image($r('app.media.me_go'))
    Blank().width(6).height(12)
'@
  'College rejects missing image' = $collegeTitle
  'College rejects approved image only in line comment' = $collegeTitle + @'

    // Image($r('app.media.me_go')).width(6).height(12)
'@
  'College rejects approved image only in block comment' = $collegeTitle + @'

    /* Image($r('app.media.me_go')).width(6).height(12) */
'@
  'College rejects approved image only in ordinary string' = $collegeTitle + @'

    Text('Image($r(''app.media.me_go'')).width(6).height(12)')
'@
  'College rejects approved image only in template raw text' = $collegeTitle + @'

    Text(`Image($r('app.media.me_go')).width(6).height(12)`)
'@
  'College rejects approved resource only in prefixed FakeImage' = $collegeTitle + @'

    FakeImage($r('app.media.me_go')).width(6).height(12)
'@
  'College rejects title only in ordinary string' = @'

    Text('Text(appString(collegeAdapterViewTitleKey))')
    Image($r('app.media.me_go')).width(6).height(12)
'@
  'College rejects title only in prefixed FakeText' = @'

    FakeText(appString(collegeAdapterViewTitleKey))
    Image($r('app.media.me_go')).width(6).height(12)
'@
  'College rejects line-start single-quoted Text placeholder' = $collegeValidLineStart + @'

    Text('>')
'@
  'College rejects inline single-quoted Text placeholder' = $collegeValidLineStart + @'

    Row() { Text('>') }
'@
  'College rejects multiline single-quoted Text placeholder' = $collegeValidLineStart + @'

    Text(
      '>'
    )
'@
  'College rejects line-start double-quoted Text placeholder' = $collegeValidLineStart + @'

    Text(">")
'@
  'College rejects inline double-quoted Text placeholder' = $collegeValidLineStart + @'

    Row() { Text(">") }
'@
  'College rejects multiline double-quoted Text placeholder' = $collegeValidLineStart + @'

    Text(
      ">"
    )
'@
}

foreach ($case in $collegeRejectCases.GetEnumerator()) {
  $source = New-CollegeFixture $case.Value
  Assert-GuardRejects $case.Key { Assert-CollegeSourceContract $source }
}

$collegeSiblingOnly = New-CollegeFixture $collegeTitle @'

    Image($r('app.media.me_go')).width(6).height(12)
'@
Assert-GuardRejects 'College rejects approved chevron only in sibling method' {
  Assert-CollegeSourceContract $collegeSiblingOnly
}

$collegePlaceholderInSibling = New-CollegeFixture $collegeValidLineStart @'

    Row() { Text('>') }
'@
Assert-GuardAccepts 'College ignores Text placeholder only in sibling method' {
  Assert-CollegeSourceContract $collegePlaceholderInSibling
}

$collegeFakeMethodSources = [ordered]@{
  'College rejects block-comment fake entry method' = @'
/*
  private collegeEntryCard(item: CollegeItem) {
    Text(appString(collegeAdapterViewTitleKey))
    Image($r('app.media.me_go')).width(6).height(12)
  }
*/
'@
  'College rejects template-raw fake entry method' = @'
const fake = `
  private collegeEntryCard(item: CollegeItem) {
    Text(appString(collegeAdapterViewTitleKey))
    Image($r('app.media.me_go')).width(6).height(12)
  }
`;
'@
}

foreach ($case in $collegeFakeMethodSources.GetEnumerator()) {
  $source = $case.Value
  Assert-GuardRejects $case.Key { Assert-CollegeSourceContract $source }
}

$collegeUnclosed = @'
@Component
struct Fixture {
  @Builder
  private collegeEntryCard(item: CollegeItem) {
    Text(appString(collegeAdapterViewTitleKey))
    Image($r('app.media.me_go')).width(6).height(12)
'@
Assert-GuardRejects 'College rejects an unclosed entry method' {
  Assert-CollegeSourceContract $collegeUnclosed
}

if ($script:failures.Count -gt 0) {
  $script:failures | ForEach-Object { Write-Host "FAILED: $_" }
  throw "ArkTS image source guard mutation fixtures failed: $($script:failures.Count) failed, $script:passed passed"
}

Write-Host "ArkTS image source guard mutation fixtures passed: $script:passed"
