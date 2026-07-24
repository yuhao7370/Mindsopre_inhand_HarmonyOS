$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-runtime-ui-evidence.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-runtime-evidence-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Runtime evidence fixture refused an unsafe temporary path.'
}

function Attrs(
  [string]$Type,
  [string]$Bounds,
  [string]$Text = '',
  [string]$Clickable = 'false',
  [string]$Scrollable = 'false'
) {
  return [ordered]@{
    abilityName = ''
    bundleName = ''
    pagePath = ''
    type = $Type
    bounds = $Bounds
    text = $Text
    originalText = $Text
    description = ''
    id = ''
    backgroundImage = ''
    clickable = $Clickable
    enabled = 'true'
    scrollable = $Scrollable
    visible = 'true'
  }
}

function New-Fixture([string]$Root) {
  [IO.Directory]::CreateDirectory($Root) | Out-Null
  $hap = Join-Path $Root 'entry-default-unsigned.hap'
  $shot = Join-Path $Root 'initial.jpeg'
  $layoutPath = Join-Path $Root 'initial.json'
  $aa = Join-Path $Root 'aa-dump.txt'
  [IO.File]::WriteAllBytes($hap, [byte[]](1, 2, 3, 4))
  [IO.File]::WriteAllBytes($shot, [byte[]](255, 216, 255, 217))
  [IO.File]::WriteAllText(
    $aa,
    'app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND',
    $utf8
  )

  $rootAttrs = Attrs 'root' '[0,0][400,800]'
  $rootAttrs.abilityName = 'EntryAbility'
  $rootAttrs.bundleName = 'com.yuhaofeng.mih'
  $rootAttrs.pagePath = 'pages/FeatureRuntimePage'
  $layout = [ordered]@{
    attributes = $rootAttrs
    children = @(
      [ordered]@{
        attributes = (Attrs 'Scroll' '[0,0][400,700]' '' 'false' 'true')
        children = @(
          [ordered]@{ attributes = (Attrs 'Image' '[20,100][220,300]'); children = @() },
          [ordered]@{ attributes = (Attrs 'Text' '[20,320][380,370]' 'Initial'); children = @() },
          [ordered]@{ attributes = (Attrs 'Button' '[20,600][180,650]' 'Retry' 'true'); children = @() },
          [ordered]@{ attributes = (Attrs 'Button' '[200,600][360,650]' 'Settings' 'true'); children = @() }
        )
      }
    )
  }
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
  $hapHash = (Get-FileHash -LiteralPath $hap -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest = [ordered]@{
    task = 1
    candidateDiffSha256 = ('a' * 64)
    hapPath = $hap
    hapSha256 = $hapHash
    commitSha = ''
    routeName = '/imageobject/ObjectPhotoActivity'
    fontScale = 1.0
    source = 'production'
    density = 1.0
    permissionBefore = [ordered]@{ camera = -1; media = -1 }
    permissionAfter = [ordered]@{ camera = 0; media = -1 }
    aaDumpPath = $aa
    states = @(
      [ordered]@{
        name = 'initial'
        layout = $layoutPath
        screenshot = $shot
        pagePath = 'pages/FeatureRuntimePage'
        scrollableCount = 1
        requiredTexts = @('Initial')
        forbiddenTexts = @('Hidden model')
        requiredClickableTexts = @('Retry', 'Settings')
        minTargetVp = 44
        minPrimaryTargetVp = 48
        bottomInsetPx = 20
        preservedBoundsHashFrom = ''
      }
    )
  }
  $manifestPath = Join-Path $Root 'manifest.json'
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  return $manifestPath
}

function Assert-Rejected([string]$Name, [scriptblock]$Mutation) {
  $root = Join-Path $tempRoot $Name
  $manifestPath = New-Fixture $root
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  $layoutPath = [string]$manifest.states[0].layout
  $layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding utf8 | ConvertFrom-Json
  & $Mutation $manifest $layout $root
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  $rejected = $false
  try { & $guardPath -ManifestPath $manifestPath | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "Runtime evidence guard accepted mutation: $Name" }
}

try {
  $validPath = New-Fixture (Join-Path $tempRoot 'valid')
  & $guardPath -ManifestPath $validPath | Out-Null

  Assert-Rejected 'task' { param($m, $l, $r) $m.task = 0 }
  Assert-Rejected 'candidate-hash' { param($m, $l, $r) $m.candidateDiffSha256 = 'decoy' }
  Assert-Rejected 'missing-hap' { param($m, $l, $r) $m.hapPath = (Join-Path $r 'missing.hap') }
  Assert-Rejected 'hap-hash' { param($m, $l, $r) $m.hapSha256 = ('0' * 64) }
  Assert-Rejected 'commit-sha' { param($m, $l, $r) $m.commitSha = 'pending' }
  Assert-Rejected 'route' { param($m, $l, $r) $m.routeName = '/wrong/Route' }
  Assert-Rejected 'font-scale' { param($m, $l, $r) $m.fontScale = 2.0 }
  Assert-Rejected 'font-source' { param($m, $l, $r) $m.fontScale = 3.2; $m.source = 'production' }
  Assert-Rejected 'source' { param($m, $l, $r) $m.source = 'manual' }
  Assert-Rejected 'density' { param($m, $l, $r) $m.density = 0 }
  Assert-Rejected 'permission-before' { param($m, $l, $r) $m.permissionBefore.camera = 9 }
  Assert-Rejected 'permission-after' { param($m, $l, $r) $m.permissionAfter.media = 9 }
  Assert-Rejected 'aa-dump' {
    param($m, $l, $r)
    [IO.File]::WriteAllText(
      [string]$m.aaDumpPath,
      'app name [com.yuhaofeng.mih] main name [EntryAbility] state #BACKGROUND',
      $utf8
    )
  }
  Assert-Rejected 'states' { param($m, $l, $r) $m.states = @() }
  Assert-Rejected 'state-name' { param($m, $l, $r) $m.states[0].name = '' }
  Assert-Rejected 'layout-file' { param($m, $l, $r) $m.states[0].layout = (Join-Path $r 'missing.json') }
  Assert-Rejected 'screenshot-file' { param($m, $l, $r) $m.states[0].screenshot = (Join-Path $r 'missing.jpeg') }
  Assert-Rejected 'screenshot-type' {
    param($m, $l, $r)
    $path = Join-Path $r 'shot.png'
    [IO.File]::WriteAllBytes($path, [byte[]](1))
    $m.states[0].screenshot = $path
  }
  Assert-Rejected 'page-path' { param($m, $l, $r) $m.states[0].pagePath = 'pages/Index' }
  Assert-Rejected 'scroll-count' { param($m, $l, $r) $m.states[0].scrollableCount = 0 }
  Assert-Rejected 'required-text' { param($m, $l, $r) $m.states[0].requiredTexts = @('Missing') }
  Assert-Rejected 'required-text-decoy' {
    param($m, $l, $r)
    $m.states[0].requiredTexts = @('Missing')
    $l | Add-Member -NotePropertyName decoy -NotePropertyValue 'Missing'
  }
  Assert-Rejected 'forbidden-text' { param($m, $l, $r) $m.states[0].forbiddenTexts = @('Initial') }
  Assert-Rejected 'not-clickable' {
    param($m, $l, $r)
    $l.children[0].children[2].attributes.clickable = 'false'
  }
  Assert-Rejected 'min-target' { param($m, $l, $r) $m.states[0].minTargetVp = 43 }
  Assert-Rejected 'min-primary' { param($m, $l, $r) $m.states[0].minPrimaryTargetVp = 47 }
  Assert-Rejected 'undersized-target' {
    param($m, $l, $r)
    $l.children[0].children[2].attributes.bounds = '[20,600][60,640]'
  }
  Assert-Rejected 'outside-app' {
    param($m, $l, $r)
    $l.children[0].children[1].attributes.bounds = '[-1,320][380,370]'
  }
  Assert-Rejected 'bottom-inset' {
    param($m, $l, $r)
    $m.states[0].bottomInsetPx = 170
  }
  Assert-Rejected 'overlap-actions' {
    param($m, $l, $r)
    $l.children[0].children[3].attributes.bounds = '[100,600][260,650]'
  }
  Assert-Rejected 'fixed-route-switch' {
    param($m, $l, $r)
    $m.routeName = '/imageobject/ObjectCameraActivity'
    $l.children[0].children[1].attributes.text = 'Switch camera'
    $l.children[0].children[1].attributes.originalText = 'Switch camera'
  }
  Assert-Rejected 'preservation-reference' {
    param($m, $l, $r)
    $secondLayout = Join-Path $r 'failure.json'
    $secondShot = Join-Path $r 'failure.jpeg'
    [IO.File]::WriteAllBytes($secondShot, [byte[]](255, 216, 255, 217))
    $copy = $l | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $copy.children[0].children[0].attributes.bounds = '[30,100][230,300]'
    [IO.File]::WriteAllText($secondLayout, ($copy | ConvertTo-Json -Depth 20), $utf8)
    $state = $m.states[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $state.name = 'failure'
    $state.layout = $secondLayout
    $state.screenshot = $secondShot
    $state.preservedBoundsHashFrom = 'initial'
    $m.states = @($m.states[0], $state)
  }

  Write-Output 'Runtime UI evidence guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Runtime evidence fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
