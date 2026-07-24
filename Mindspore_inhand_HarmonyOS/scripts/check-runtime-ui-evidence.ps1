param(
  [Parameter(Mandatory = $true)]
  [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Runtime UI evidence check failed: $Message"
}

function Require-Property([object]$Object, [string]$Name) {
  if ($null -eq $Object -or $Object.PSObject.Properties.Name -notcontains $Name) {
    Fail "missing property '$Name'."
  }
  return $Object.$Name
}

function Require-AbsoluteFile([string]$Path, [string]$Label) {
  if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path) -or
    -not [IO.File]::Exists($Path) -or ([IO.FileInfo]$Path).Length -le 0) {
    Fail "$Label must be an absolute, non-empty file."
  }
}

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
}

function Get-TextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes((Normalize-Text $Text))
  return ([BitConverter]::ToString(
      [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    )).Replace('-', '').ToLowerInvariant()
}

function Flatten-Nodes([object]$Node) {
  $items = [Collections.Generic.List[object]]::new()
  if ($null -eq $Node) { return $items }
  $items.Add($Node)
  if ($Node.PSObject.Properties.Name -contains 'children' -and $null -ne $Node.children) {
    foreach ($child in @($Node.children)) {
      foreach ($item in @(Flatten-Nodes $child)) { $items.Add($item) }
    }
  }
  return $items
}

function Parse-Bounds([string]$Bounds) {
  $match = [regex]::Match($Bounds, '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $match.Success) { return $null }
  return [pscustomobject]@{
    Left = [int]$match.Groups[1].Value
    Top = [int]$match.Groups[2].Value
    Right = [int]$match.Groups[3].Value
    Bottom = [int]$match.Groups[4].Value
    Width = [int]$match.Groups[3].Value - [int]$match.Groups[1].Value
    Height = [int]$match.Groups[4].Value - [int]$match.Groups[2].Value
  }
}

function Attr([object]$Node, [string]$Name) {
  if ($null -eq $Node.attributes -or $Node.attributes.PSObject.Properties.Name -notcontains $Name) { return '' }
  return [string]$Node.attributes.$Name
}

function Is-Visible([object]$Node) {
  $visible = Attr $Node 'visible'
  return [string]::IsNullOrEmpty($visible) -or $visible -eq 'true'
}

function Node-Label([object]$Node) {
  foreach ($name in @('text', 'originalText', 'description')) {
    $value = Attr $Node $name
    if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
  }
  return ''
}

function Get-PreservationNode([object[]]$Nodes, [string]$Selector, [string]$StateName) {
  $separator = $Selector.IndexOf(':', [StringComparison]::Ordinal)
  if ($separator -le 0 -or $separator -eq $Selector.Length - 1) {
    Fail "state '$StateName' has an invalid preservedNodeSelector '$Selector'."
  }
  $kind = $Selector.Substring(0, $separator)
  $value = $Selector.Substring($separator + 1)
  $matches = @(switch ($kind) {
    'id' { @($Nodes | Where-Object { (Attr $_ 'id') -ceq $value }) }
    'key' { @($Nodes | Where-Object { (Attr $_ 'key') -ceq $value }) }
    'text' { @($Nodes | Where-Object { (Node-Label $_) -ceq $value }) }
    'type' { @($Nodes | Where-Object { (Attr $_ 'type') -ceq $value }) }
    default { @() }
  })
  if ($matches.Count -ne 1) {
    Fail "state '$StateName' selector '$Selector' must identify exactly one captured subtree; found $($matches.Count)."
  }
  return $matches[0]
}

function Get-PreservationHash([object]$Node) {
  $stableNames = @(
    'type', 'id', 'key', 'text', 'originalText', 'description', 'bounds',
    'backgroundImage', 'selected', 'checked', 'enabled', 'visible'
  )
  $parts = [Collections.Generic.List[string]]::new()
  foreach ($name in $stableNames) {
    $parts.Add("$name=$(Attr $Node $name)")
  }
  if ($Node.PSObject.Properties.Name -contains 'children' -and $null -ne $Node.children) {
    foreach ($child in @($Node.children)) {
      $parts.Add("child=$(Get-PreservationHash $child)")
    }
  }
  return Get-TextSha256 ($parts -join "`n")
}

$ManifestPath = [IO.Path]::GetFullPath($ManifestPath)
Require-AbsoluteFile $ManifestPath 'ManifestPath'
try {
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
} catch {
  Fail 'manifest must be valid UTF-8 JSON.'
}

$task = Require-Property $manifest 'task'
if ($task -isnot [int] -or $task -lt 1 -or $task -gt 18) { Fail 'task must be an integer from 1 through 18.' }
$candidateHash = [string](Require-Property $manifest 'candidateDiffSha256')
if ($candidateHash -notmatch '^[0-9a-f]{64}$') { Fail 'candidateDiffSha256 must be 64 hex characters.' }
$repositoryRoot = [string](Require-Property $manifest 'repositoryRoot')
if ([string]::IsNullOrWhiteSpace($repositoryRoot) -or -not [IO.Path]::IsPathRooted($repositoryRoot) -or
  -not [IO.Directory]::Exists($repositoryRoot)) {
  Fail 'repositoryRoot must be an existing absolute directory.'
}
$repositoryRoot = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
$resolvedGitRoot = Normalize-Text ((& git -C $repositoryRoot rev-parse --show-toplevel 2>$null) -join "`n")
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($resolvedGitRoot).TrimEnd('\', '/') -cne $repositoryRoot) {
  Fail 'repositoryRoot must be the exact Git worktree root.'
}
$candidateDiffPath = [string](Require-Property $manifest 'candidateDiffPath')
Require-AbsoluteFile $candidateDiffPath 'candidateDiffPath'
if ((Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
  $candidateHash.ToLowerInvariant()) {
  Fail 'candidateDiffSha256 does not match candidateDiffPath.'
}
$hapPath = [string](Require-Property $manifest 'hapPath')
Require-AbsoluteFile $hapPath 'hapPath'
$hapHash = [string](Require-Property $manifest 'hapSha256')
if ($hapHash -notmatch '^[0-9a-f]{64}$') { Fail 'hapSha256 must be 64 hex characters.' }
$actualHapHash = (Get-FileHash -LiteralPath $hapPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHapHash -cne $hapHash) { Fail 'hapSha256 does not match hapPath.' }
$commitSha = [string](Require-Property $manifest 'commitSha')
if ($commitSha -ne '' -and $commitSha -notmatch '^[0-9a-f]{40}$') { Fail 'commitSha must be empty or 40 hex characters.' }
$headSha = Normalize-Text ((& git -C $repositoryRoot rev-parse HEAD 2>$null) -join "`n")
$statusText = Normalize-Text ((& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all 2>$null) -join "`n")
if ($commitSha -eq '') {
  if ($statusText -match '(?m)^\?\? ') {
    Fail 'an uncommitted evidence candidate must not contain untracked files outside the Git diff.'
  }
  $gitDiff = Normalize-Text ((& git -C $repositoryRoot diff --binary HEAD -- 2>$null) -join "`n")
} else {
  $resolvedCommit = Normalize-Text ((& git -C $repositoryRoot rev-parse $commitSha 2>$null) -join "`n")
  if ($LASTEXITCODE -ne 0 -or $resolvedCommit -cne $commitSha -or $headSha -cne $commitSha) {
    Fail 'commitSha must resolve to the captured worktree HEAD.'
  }
  $gitDiff = Normalize-Text ((& git -C $repositoryRoot diff --binary "$commitSha^" $commitSha -- 2>$null) -join "`n")
}
if ((Normalize-Text ([IO.File]::ReadAllText($candidateDiffPath))) -cne $gitDiff) {
  Fail 'candidateDiffPath is not the actual Git candidate diff.'
}

$runtimeRoutes = @(
  '/imageobject/ObjectPhotoActivity', '/imageobject/ObjectCameraActivity', '/imageobject/ImageCameraActivity',
  '/styletransfer/StyleMainActivity', '/custommodel/CustomModelMainActivity', '/hms/PosenetMainActivitys',
  '/posenet/LiveSkeletonAnalyseActivity', '/hms/ImageSegmentationActivity',
  '/hms/ImageSegmentationLiveAnalyseActivity', '/hms/PortraitSegmentationActivity',
  '/hms/SenceDetectionStillAnalyseActivity', '/hms/SenceDetectionLiveAnalyseActivity',
  '/hms/StillHandGestureAnalyseActivity', '/hms/LiveHandGestureAnalyseActivity',
  '/hms/TextRecognitionActivity', '/hms/TextTranslationActivity'
)
$switchCameraZh = -join @(0x5207, 0x6362, 0x6444, 0x50CF, 0x5934 | ForEach-Object { [char]$_ })
$routeName = [string](Require-Property $manifest 'routeName')
if ($runtimeRoutes -cnotcontains $routeName) { Fail 'routeName is not an exact FeatureRuntime AppRoute name.' }
$fontScale = [double](Require-Property $manifest 'fontScale')
if ($fontScale -notin @(1.0, 3.2)) { Fail 'fontScale must be 1.0 or 3.2.' }
$sourceKind = [string](Require-Property $manifest 'source')
if ($sourceKind -notin @('production', 'harness')) { Fail 'source must be production or harness.' }
if (($fontScale -eq 3.2 -or $routeName -eq '/custommodel/CustomModelMainActivity') -and $sourceKind -ne 'harness') {
  Fail '3.2x and hidden-route evidence must come from the isolated harness.'
}
$density = [double](Require-Property $manifest 'density')
if ($density -le 0) { Fail 'density must be positive.' }
$captureEnvironmentPath = [string](Require-Property $manifest 'captureEnvironmentPath')
Require-AbsoluteFile $captureEnvironmentPath 'captureEnvironmentPath'
try {
  $captureEnvironment = Get-Content -LiteralPath $captureEnvironmentPath -Raw -Encoding utf8 | ConvertFrom-Json
} catch {
  Fail 'captureEnvironmentPath must contain valid UTF-8 JSON.'
}
if ([string](Require-Property $captureEnvironment 'source') -cne $sourceKind -or
  [double](Require-Property $captureEnvironment 'fontScale') -ne $fontScale -or
  [double](Require-Property $captureEnvironment 'density') -ne $density -or
  [string](Require-Property $captureEnvironment 'repositoryRoot') -cne $repositoryRoot -or
  [string](Require-Property $captureEnvironment 'gitHead') -cne $headSha) {
  Fail 'capture environment does not bind source/font/density/repository/HEAD claims.'
}
if ([string](Require-Property $captureEnvironment 'gitStatusSha256') -cne (Get-TextSha256 $statusText)) {
  Fail 'capture environment git status does not match the worktree.'
}
$displayWidthPx = [int](Require-Property $captureEnvironment 'displayWidthPx')
$displayHeightPx = [int](Require-Property $captureEnvironment 'displayHeightPx')
if ($displayWidthPx -le 0 -or $displayHeightPx -le 0) {
  Fail 'capture environment display dimensions must be positive.'
}

foreach ($permissionField in @('permissionBefore', 'permissionAfter')) {
  $permission = Require-Property $manifest $permissionField
  foreach ($kind in @('camera', 'media')) {
    $value = Require-Property $permission $kind
    if ($value -isnot [int] -or $value -notin @(-1, 0, 1, 2)) {
      Fail "$permissionField.$kind must be a known permission-state integer."
    }
  }
}
$permissionProofPaths = @{
  permissionBefore = [string](Require-Property $manifest 'permissionBeforePath')
  permissionAfter = [string](Require-Property $manifest 'permissionAfterPath')
}
foreach ($permissionField in @('permissionBefore', 'permissionAfter')) {
  $proofPath = $permissionProofPaths[$permissionField]
  Require-AbsoluteFile $proofPath "$permissionField proof"
  try {
    $proof = Get-Content -LiteralPath $proofPath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    Fail "$permissionField proof must be the JSON output from the permission-state command."
  }
  if ([string](Require-Property $proof 'bundleName') -cne 'com.yuhaofeng.mih') {
    Fail "$permissionField proof has the wrong bundle."
  }
  $statesByName = @{}
  foreach ($entry in @((Require-Property $proof 'permStateList'))) {
    $statesByName[[string](Require-Property $entry 'permissionName')] = [int](Require-Property $entry 'grantStatus')
  }
  if (-not $statesByName.ContainsKey('ohos.permission.CAMERA') -or
    -not $statesByName.ContainsKey('ohos.permission.READ_IMAGEVIDEO') -or
    $statesByName['ohos.permission.CAMERA'] -ne [int]$manifest.$permissionField.camera -or
    $statesByName['ohos.permission.READ_IMAGEVIDEO'] -ne [int]$manifest.$permissionField.media) {
    Fail "$permissionField does not match its captured permission-state JSON."
  }
}

$aaDumpPath = [string](Require-Property $manifest 'aaDumpPath')
Require-AbsoluteFile $aaDumpPath 'aaDumpPath'
$aaDump = [IO.File]::ReadAllText($aaDumpPath)
if ($aaDump -notmatch '(?s)app name \[com\.yuhaofeng\.mih\].{0,500}main name \[EntryAbility\].{0,500}state #FOREGROUND') {
  Fail 'aa dump does not prove the application EntryAbility is foreground.'
}

$states = @(Require-Property $manifest 'states')
if ($states.Count -eq 0) { Fail 'states must contain at least one captured state.' }
$stateData = @{}
foreach ($state in $states) {
  $name = [string](Require-Property $state 'name')
  if ([string]::IsNullOrWhiteSpace($name) -or $stateData.ContainsKey($name)) { Fail 'state names must be unique and non-empty.' }
  $layoutPath = [string](Require-Property $state 'layout')
  $screenshotPath = [string](Require-Property $state 'screenshot')
  Require-AbsoluteFile $layoutPath "state '$name' layout"
  Require-AbsoluteFile $screenshotPath "state '$name' screenshot"
  if ([IO.Path]::GetExtension($screenshotPath).ToLowerInvariant() -notin @('.jpg', '.jpeg')) {
    Fail "state '$name' screenshot must be JPEG."
  }
  $screenshotBytes = [IO.File]::ReadAllBytes($screenshotPath)
  if ($screenshotBytes.Length -lt 4 -or $screenshotBytes[0] -ne 0xFF -or $screenshotBytes[1] -ne 0xD8 -or
    $screenshotBytes[$screenshotBytes.Length - 2] -ne 0xFF -or $screenshotBytes[$screenshotBytes.Length - 1] -ne 0xD9) {
    Fail "state '$name' screenshot does not contain JPEG markers."
  }
  try {
    Add-Type -AssemblyName System.Drawing
    $decodedScreenshot = [Drawing.Image]::FromFile($screenshotPath)
    $screenshotWidth = $decodedScreenshot.Width
    $screenshotHeight = $decodedScreenshot.Height
    $decodedScreenshot.Dispose()
  } catch {
    Fail "state '$name' screenshot is not a decodable JPEG."
  }
  if ($screenshotWidth -ne $displayWidthPx -or $screenshotHeight -ne $displayHeightPx) {
    Fail "state '$name' screenshot dimensions do not match the captured display."
  }
  try { $layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding utf8 | ConvertFrom-Json } catch {
    Fail "state '$name' layout must be valid UTF-8 JSON."
  }
  $allNodes = @(Flatten-Nodes $layout)
  $displayBounds = Parse-Bounds (Attr $layout 'bounds')
  if ($null -eq $displayBounds -or $displayBounds.Width -ne $displayWidthPx -or
    $displayBounds.Height -ne $displayHeightPx) {
    Fail "state '$name' layout root does not match the captured display dimensions."
  }
  $appRoot = @($allNodes | Where-Object {
      (Attr $_ 'bundleName') -eq 'com.yuhaofeng.mih' -and (Attr $_ 'abilityName') -eq 'EntryAbility'
    })
  if ($appRoot.Count -ne 1) { Fail "state '$name' must contain exactly one application root." }
  $pagePath = [string](Require-Property $state 'pagePath')
  if ($pagePath -cne 'pages/FeatureRuntimePage' -or (Attr $appRoot[0] 'pagePath') -cne $pagePath) {
    Fail "state '$name' has the wrong pagePath."
  }
  $nodes = @(Flatten-Nodes $appRoot[0])
  if (@($nodes | Where-Object { (Attr $_ 'key') -ceq $routeName }).Count -ne 1) {
    Fail "state '$name' does not bind routeName to the captured runtime root key."
  }
  $scrollableCount = Require-Property $state 'scrollableCount'
  if ($scrollableCount -isnot [int] -or $scrollableCount -lt 0) { Fail "state '$name' scrollableCount is invalid." }
  $actualScrolls = @($nodes | Where-Object { (Is-Visible $_) -and (Attr $_ 'type') -eq 'Scroll' }).Count
  if ($actualScrolls -ne $scrollableCount) { Fail "state '$name' scrollableCount does not match the dump." }

  $requiredTexts = @(Require-Property $state 'requiredTexts')
  $forbiddenTexts = @(Require-Property $state 'forbiddenTexts')
  $requiredClickableTexts = @(Require-Property $state 'requiredClickableTexts')
  if ($requiredTexts.Count -eq 0 -or $requiredClickableTexts.Count -eq 0) {
    Fail "state '$name' must declare required state text and actions."
  }
  $labels = @($nodes | Where-Object { Is-Visible $_ } | ForEach-Object { Node-Label $_ })
  foreach ($text in $requiredTexts) {
    if ([string]::IsNullOrWhiteSpace([string]$text) -or $labels -cnotcontains [string]$text) {
      Fail "state '$name' is missing required text '$text'."
    }
  }
  foreach ($text in $forbiddenTexts) {
    if (-not [string]::IsNullOrWhiteSpace([string]$text) -and $labels -ccontains [string]$text) {
      Fail "state '$name' contains forbidden text '$text'."
    }
  }
  if ($routeName -in @('/imageobject/ObjectCameraActivity', '/imageobject/ImageCameraActivity') -and
    ($labels -contains $switchCameraZh -or $labels -contains 'Switch camera')) {
    Fail "state '$name' exposes a camera switch on a fixed-camera route."
  }

  $minTargetVp = [double](Require-Property $state 'minTargetVp')
  $minPrimaryTargetVp = [double](Require-Property $state 'minPrimaryTargetVp')
  $bottomInsetPx = [int](Require-Property $state 'bottomInsetPx')
  if ($minTargetVp -lt 44 -or $minPrimaryTargetVp -lt 48 -or $bottomInsetPx -le 0) {
    Fail "state '$name' has invalid target or inset thresholds."
  }
  $appBounds = Parse-Bounds (Attr $appRoot[0] 'bounds')
  if ($null -eq $appBounds -or $appBounds.Width -le 0 -or $appBounds.Height -le 0) {
    Fail "state '$name' application bounds are invalid."
  }
  if ($bottomInsetPx -ne ($displayHeightPx - $appBounds.Bottom)) {
    Fail "state '$name' bottomInsetPx does not match the captured display/application bounds."
  }
  $clickableBounds = [Collections.Generic.List[object]]::new()
  foreach ($node in $nodes | Where-Object { Is-Visible $_ }) {
    $boundsText = Attr $node 'bounds'
    if ([string]::IsNullOrWhiteSpace($boundsText)) { continue }
    $bounds = Parse-Bounds $boundsText
    if ($null -eq $bounds -or $bounds.Width -lt 0 -or $bounds.Height -lt 0 -or
      $bounds.Left -lt $appBounds.Left -or $bounds.Top -lt $appBounds.Top -or
      $bounds.Right -gt $appBounds.Right -or $bounds.Bottom -gt $appBounds.Bottom) {
      Fail "state '$name' contains visible bounds outside the application area."
    }
    $label = Node-Label $node
    if (-not [string]::IsNullOrWhiteSpace($label) -and ($bounds.Width -le 0 -or $bounds.Height -le 0)) {
      Fail "state '$name' contains a hidden/clipped label."
    }
    if ((Attr $node 'clickable') -eq 'true') {
      if (($bounds.Width / $density) -lt $minTargetVp -or ($bounds.Height / $density) -lt $minTargetVp) {
        Fail "state '$name' contains an undersized clickable target."
      }
      if ($bounds.Bottom -gt ($appBounds.Bottom - $bottomInsetPx)) {
        Fail "state '$name' contains a clickable target inside the bottom inset."
      }
      $clickableBounds.Add($bounds)
    }
  }
  for ($left = 0; $left -lt $clickableBounds.Count; $left++) {
    for ($right = $left + 1; $right -lt $clickableBounds.Count; $right++) {
      $a = $clickableBounds[$left]
      $b = $clickableBounds[$right]
      if ([Math]::Max($a.Left, $b.Left) -lt [Math]::Min($a.Right, $b.Right) -and
        [Math]::Max($a.Top, $b.Top) -lt [Math]::Min($a.Bottom, $b.Bottom)) {
        Fail "state '$name' contains overlapping visible clickable actions."
      }
    }
  }

  $requiredControls = @()
  foreach ($text in $requiredClickableTexts) {
    $matches = @($nodes | Where-Object {
        (Is-Visible $_) -and (Node-Label $_) -ceq [string]$text -and
        (Attr $_ 'clickable') -eq 'true' -and (Attr $_ 'enabled') -ne 'false'
      })
    if ($matches.Count -ne 1) { Fail "state '$name' must contain one enabled clickable '$text'." }
    $bounds = Parse-Bounds (Attr $matches[0] 'bounds')
    if (($bounds.Width / $density) -lt $minPrimaryTargetVp -or ($bounds.Height / $density) -lt $minPrimaryTargetVp) {
      Fail "state '$name' primary control '$text' is undersized."
    }
    $requiredControls += $bounds
  }
  $preservedFrom = [string](Require-Property $state 'preservedBoundsHashFrom')
  $preservedSelectors = @((Require-Property $state 'preservedNodeSelectors'))
  $preservedHashes = @{}
  foreach ($selector in $preservedSelectors) {
    $preservedHashes[[string]$selector] = Get-PreservationHash (
      Get-PreservationNode $nodes ([string]$selector) $name
    )
  }
  $stateData[$name] = [pscustomobject]@{
    PreserveFrom = $preservedFrom
    Selectors = $preservedSelectors
    Hashes = $preservedHashes
  }
}

foreach ($name in $stateData.Keys) {
  $reference = $stateData[$name].PreserveFrom
  if ($reference -eq '') { continue }
  if (-not $stateData.ContainsKey($reference) -or $reference -ceq $name -or
    $stateData[$name].Selectors.Count -eq 0 -or
    ($stateData[$name].Selectors -join "`n") -cne ($stateData[$reference].Selectors -join "`n")) {
    Fail "state '$name' does not preserve the referenced visual bounds."
  }
  foreach ($selector in $stateData[$name].Selectors) {
    if ($stateData[$name].Hashes[[string]$selector] -cne $stateData[$reference].Hashes[[string]$selector]) {
      Fail "state '$name' changed preserved subtree '$selector'."
    }
  }
}

Write-Output 'Runtime UI evidence manifest passed.'
