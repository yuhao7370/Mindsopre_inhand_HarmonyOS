$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-runtime-ui-evidence.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-runtime-evidence-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Runtime evidence fixture refused an unsafe temporary path.'
}

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
}

function Get-TextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes((Normalize-Text $Text))
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Attrs(
  [string]$Type,
  [string]$Bounds,
  [string]$Text = '',
  [string]$Clickable = 'false',
  [string]$Scrollable = 'false',
  [string]$Key = ''
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
    key = $Key
    backgroundImage = ''
    clickable = $Clickable
    enabled = 'true'
    scrollable = $Scrollable
    visible = 'true'
  }
}

function Write-Jpeg([string]$Path, [int]$Width = 400, [int]$Height = 800) {
  Add-Type -AssemblyName System.Drawing
  $bitmap = [Drawing.Bitmap]::new($Width, $Height)
  try {
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Jpeg)
  } finally {
    $bitmap.Dispose()
  }
}

function Write-PermissionProof([string]$Path, [int]$Camera, [int]$Media) {
  $proof = [ordered]@{
    bundleName = 'com.yuhaofeng.mih'
    permStateList = @(
      [ordered]@{ permissionName = 'ohos.permission.CAMERA'; grantStatus = $Camera },
      [ordered]@{ permissionName = 'ohos.permission.READ_IMAGEVIDEO'; grantStatus = $Media }
    )
  }
  [IO.File]::WriteAllText($Path, ($proof | ConvertTo-Json -Depth 10), $utf8)
}

function Invoke-Git([string]$RepositoryRoot, [string[]]$Arguments) {
  $output = @(& git -C $RepositoryRoot @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) {
    throw "Fixture git command failed: git $($Arguments -join ' ')`n$($output -join "`n")"
  }
  return Normalize-Text ($output -join "`n")
}

function New-Fixture([string]$Root) {
  [IO.Directory]::CreateDirectory($Root) | Out-Null
  $repositoryRoot = Join-Path $Root 'repo'
  [IO.Directory]::CreateDirectory($repositoryRoot) | Out-Null
  Invoke-Git $repositoryRoot @('init', '--quiet') | Out-Null
  Invoke-Git $repositoryRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-Git $repositoryRoot @('config', 'user.email', 'runtime-fixture@example.invalid') | Out-Null
  Invoke-Git $repositoryRoot @('config', 'user.name', 'Runtime Fixture') | Out-Null
  $candidateFile = Join-Path $repositoryRoot 'candidate.txt'
  [IO.File]::WriteAllText($candidateFile, "baseline`n", $utf8)
  Invoke-Git $repositoryRoot @('add', '--', 'candidate.txt') | Out-Null
  Invoke-Git $repositoryRoot @('commit', '--quiet', '-m', 'fixture baseline') | Out-Null
  [IO.File]::WriteAllText($candidateFile, "candidate change`n", $utf8)

  $candidateDiffPath = Join-Path $Root 'candidate.diff'
  [IO.File]::WriteAllText(
    $candidateDiffPath,
    (Invoke-Git $repositoryRoot @('diff', '--binary', 'HEAD', '--')),
    $utf8
  )
  $candidateHash = (Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $gitHead = Invoke-Git $repositoryRoot @('rev-parse', 'HEAD')
  $gitStatus = Invoke-Git $repositoryRoot @('status', '--porcelain=v1', '--untracked-files=all')

  $hap = Join-Path $Root 'entry-default-unsigned.hap'
  $shot = Join-Path $Root 'initial.jpeg'
  $layoutPath = Join-Path $Root 'initial.json'
  $aa = Join-Path $Root 'aa-dump.txt'
  $captureEnvironmentPath = Join-Path $Root 'capture-environment.json'
  $permissionBeforePath = Join-Path $Root 'permission-before.json'
  $permissionAfterPath = Join-Path $Root 'permission-after.json'
  [IO.File]::WriteAllBytes($hap, [byte[]](1, 2, 3, 4))
  Write-Jpeg $shot
  [IO.File]::WriteAllText(
    $aa,
    'app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND',
    $utf8
  )
  Write-PermissionProof $permissionBeforePath -1 -1
  Write-PermissionProof $permissionAfterPath 0 -1

  $captureEnvironment = [ordered]@{
    source = 'production'
    fontScale = 1.0
    density = 1.0
    repositoryRoot = $repositoryRoot
    gitHead = $gitHead
    gitStatusSha256 = Get-TextSha256 $gitStatus
    displayWidthPx = 400
    displayHeightPx = 800
  }
  [IO.File]::WriteAllText(
    $captureEnvironmentPath,
    ($captureEnvironment | ConvertTo-Json -Depth 10),
    $utf8
  )

  $displayAttrs = Attrs 'root' '[0,0][400,800]'
  $appAttrs = Attrs 'Stack' '[0,0][400,780]' '' 'false' 'false' '/imageobject/ObjectPhotoActivity'
  $appAttrs.abilityName = 'EntryAbility'
  $appAttrs.bundleName = 'com.yuhaofeng.mih'
  $appAttrs.pagePath = 'pages/FeatureRuntimePage'
  $imageAttrs = Attrs 'Image' '[20,100][220,300]'
  $imageAttrs.id = 'runtime-image'
  $imageAttrs.backgroundImage = 'pixelmap://initial'
  $layout = [ordered]@{
    attributes = $displayAttrs
    children = @(
      [ordered]@{
        attributes = $appAttrs
        children = @(
          [ordered]@{
            attributes = (Attrs 'Scroll' '[0,0][400,760]' '' 'false' 'true')
            children = @(
              [ordered]@{ attributes = $imageAttrs; children = @() },
              [ordered]@{ attributes = (Attrs 'Text' '[20,320][380,370]' 'Initial'); children = @() },
              [ordered]@{ attributes = (Attrs 'Button' '[20,600][180,650]' 'Retry' 'true'); children = @() },
              [ordered]@{ attributes = (Attrs 'Button' '[200,600][360,650]' 'Settings' 'true'); children = @() }
            )
          }
        )
      }
    )
  }
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
  $hapHash = (Get-FileHash -LiteralPath $hap -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest = [ordered]@{
    task = 1
    repositoryRoot = $repositoryRoot
    candidateDiffPath = $candidateDiffPath
    candidateDiffSha256 = $candidateHash
    hapPath = $hap
    hapSha256 = $hapHash
    commitSha = ''
    routeName = '/imageobject/ObjectPhotoActivity'
    fontScale = 1.0
    source = 'production'
    density = 1.0
    captureEnvironmentPath = $captureEnvironmentPath
    permissionBefore = [ordered]@{ camera = -1; media = -1 }
    permissionAfter = [ordered]@{ camera = 0; media = -1 }
    permissionBeforePath = $permissionBeforePath
    permissionAfterPath = $permissionAfterPath
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
        preservedNodeSelectors = @('id:runtime-image')
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
  Assert-Rejected 'repository-root' { param($m, $l, $r) $m.repositoryRoot = $r }
  Assert-Rejected 'candidate-hash' { param($m, $l, $r) $m.candidateDiffSha256 = 'decoy' }
  Assert-Rejected 'candidate-diff-artifact' {
    param($m, $l, $r)
    [IO.File]::WriteAllText([string]$m.candidateDiffPath, 'plausible but unrelated diff', $utf8)
    $m.candidateDiffSha256 =
      (Get-FileHash -LiteralPath ([string]$m.candidateDiffPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  Assert-Rejected 'untracked-candidate' {
    param($m, $l, $r)
    [IO.File]::WriteAllText(
      (Join-Path ([string]$m.repositoryRoot) 'untracked.txt'),
      'candidate bytes outside git diff',
      $utf8
    )
    $environment = Get-Content -LiteralPath ([string]$m.captureEnvironmentPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $environment.gitStatusSha256 = Get-TextSha256 (
      Invoke-Git ([string]$m.repositoryRoot) @('status', '--porcelain=v1', '--untracked-files=all')
    )
    [IO.File]::WriteAllText(
      [string]$m.captureEnvironmentPath,
      ($environment | ConvertTo-Json -Depth 10),
      $utf8
    )
  }
  Assert-Rejected 'missing-hap' { param($m, $l, $r) $m.hapPath = (Join-Path $r 'missing.hap') }
  Assert-Rejected 'hap-hash' { param($m, $l, $r) $m.hapSha256 = ('0' * 64) }
  Assert-Rejected 'commit-sha' { param($m, $l, $r) $m.commitSha = ('0' * 40) }
  Assert-Rejected 'route-binding' {
    param($m, $l, $r)
    $m.routeName = '/imageobject/ObjectCameraActivity'
  }
  Assert-Rejected 'font-scale-proof' { param($m, $l, $r) $m.fontScale = 3.2; $m.source = 'harness' }
  Assert-Rejected 'source-proof' { param($m, $l, $r) $m.source = 'harness' }
  Assert-Rejected 'density-proof' { param($m, $l, $r) $m.density = 2.0 }
  Assert-Rejected 'capture-status-proof' {
    param($m, $l, $r)
    $environment = Get-Content -LiteralPath ([string]$m.captureEnvironmentPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $environment.gitStatusSha256 = ('0' * 64)
    [IO.File]::WriteAllText(
      [string]$m.captureEnvironmentPath,
      ($environment | ConvertTo-Json -Depth 10),
      $utf8
    )
  }
  Assert-Rejected 'permission-before' { param($m, $l, $r) $m.permissionBefore.camera = 0 }
  Assert-Rejected 'permission-after' { param($m, $l, $r) $m.permissionAfter.media = 0 }
  Assert-Rejected 'permission-proof' {
    param($m, $l, $r)
    Write-PermissionProof ([string]$m.permissionAfterPath) -1 -1
  }
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
  Assert-Rejected 'fake-jpeg' {
    param($m, $l, $r)
    [IO.File]::WriteAllBytes([string]$m.states[0].screenshot, [byte[]](255, 216, 255, 217))
  }
  Assert-Rejected 'wrong-screenshot-dimensions' {
    param($m, $l, $r)
    Write-Jpeg ([string]$m.states[0].screenshot) 401 800
  }
  Assert-Rejected 'display-layout-mismatch' {
    param($m, $l, $r)
    $l.attributes.bounds = '[0,0][401,800]'
  }
  Assert-Rejected 'page-path' { param($m, $l, $r) $m.states[0].pagePath = 'pages/Index' }
  Assert-Rejected 'scroll-count' { param($m, $l, $r) $m.states[0].scrollableCount = 0 }
  Assert-Rejected 'empty-required-texts' { param($m, $l, $r) $m.states[0].requiredTexts = @() }
  Assert-Rejected 'empty-required-actions' { param($m, $l, $r) $m.states[0].requiredClickableTexts = @() }
  Assert-Rejected 'required-text' { param($m, $l, $r) $m.states[0].requiredTexts = @('Missing') }
  Assert-Rejected 'required-text-decoy' {
    param($m, $l, $r)
    $m.states[0].requiredTexts = @('Missing')
    $l | Add-Member -NotePropertyName decoy -NotePropertyValue 'Missing'
  }
  Assert-Rejected 'forbidden-text' { param($m, $l, $r) $m.states[0].forbiddenTexts = @('Initial') }
  Assert-Rejected 'not-clickable' {
    param($m, $l, $r)
    $l.children[0].children[0].children[2].attributes.clickable = 'false'
  }
  Assert-Rejected 'min-target' { param($m, $l, $r) $m.states[0].minTargetVp = 43 }
  Assert-Rejected 'min-primary' { param($m, $l, $r) $m.states[0].minPrimaryTargetVp = 47 }
  Assert-Rejected 'undersized-target' {
    param($m, $l, $r)
    $l.children[0].children[0].children[2].attributes.bounds = '[20,600][60,640]'
  }
  Assert-Rejected 'outside-app' {
    param($m, $l, $r)
    $l.children[0].children[0].children[1].attributes.bounds = '[-1,320][380,370]'
  }
  Assert-Rejected 'bottom-inset-zero' { param($m, $l, $r) $m.states[0].bottomInsetPx = 0 }
  Assert-Rejected 'bottom-inset-mismatch' { param($m, $l, $r) $m.states[0].bottomInsetPx = 21 }
  Assert-Rejected 'overlap-required-actions' {
    param($m, $l, $r)
    $l.children[0].children[0].children[3].attributes.bounds = '[100,600][260,650]'
  }
  Assert-Rejected 'overlap-unlisted-action' {
    param($m, $l, $r)
    $extra = [pscustomobject]@{
      attributes = (Attrs 'Button' '[100,600][260,650]' 'Unlisted' 'true')
      children = @()
    }
    $l.children[0].children[0].children += $extra
  }
  Assert-Rejected 'fixed-route-switch' {
    param($m, $l, $r)
    $m.routeName = '/imageobject/ObjectCameraActivity'
    $l.children[0].attributes.key = '/imageobject/ObjectCameraActivity'
    $l.children[0].children[0].children[1].attributes.text = 'Switch camera'
    $l.children[0].children[0].children[1].attributes.originalText = 'Switch camera'
  }
  Assert-Rejected 'preservation-selector' {
    param($m, $l, $r)
    $m.states[0].preservedNodeSelectors = @('type:Button')
  }
  Assert-Rejected 'preservation-subtree' {
    param($m, $l, $r)
    $secondLayout = Join-Path $r 'failure.json'
    $secondShot = Join-Path $r 'failure.jpeg'
    [IO.File]::Copy([string]$m.states[0].screenshot, $secondShot)
    $copy = $l | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $copy.children[0].children[0].children[0].attributes.backgroundImage = 'pixelmap://changed'
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
    foreach ($file in [IO.Directory]::GetFiles($resolved, '*', [IO.SearchOption]::AllDirectories)) {
      [IO.File]::SetAttributes($file, [IO.FileAttributes]::Normal)
    }
    foreach ($directory in @([IO.Directory]::GetDirectories(
          $resolved,
          '*',
          [IO.SearchOption]::AllDirectories
        ) | Sort-Object Length -Descending)) {
      [IO.File]::SetAttributes($directory, [IO.FileAttributes]::Directory)
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
