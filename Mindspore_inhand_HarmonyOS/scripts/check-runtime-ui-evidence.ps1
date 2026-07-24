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

function Get-StreamSha256([IO.Stream]$Stream) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-DisplayMetricValues([string]$Text, [string]$Pattern, [string]$Label) {
  $matches = @([regex]::Matches($Text, $Pattern))
  if ($matches.Count -eq 0) { Fail "display dump is missing $Label." }
  $values = @($matches | ForEach-Object { [double]$_.Groups[1].Value } | Select-Object -Unique)
  if ($values.Count -ne 1) { Fail "display dump has conflicting $Label values." }
  return [double]$values[0]
}

function Get-HapStructure([string]$Path) {
  Add-Type -AssemblyName System.IO.Compression
  $file = [IO.File]::OpenRead($Path)
  $archive = $null
  try {
    try {
      $archive = [IO.Compression.ZipArchive]::new(
        $file,
        [IO.Compression.ZipArchiveMode]::Read,
        $false
      )
    } catch {
      Fail 'hapPath must be a readable ZIP/HAP archive.'
    }
    $entries = @($archive.Entries)
    if ($entries.Count -eq 0) { Fail 'hapPath must contain packaged entries.' }
    $entryNames = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    if (@($entryNames | Group-Object | Where-Object { $_.Count -ne 1 }).Count -gt 0 -or
      @($entryNames | Where-Object { $_ -match '(^|/)\.\.(/|$)|^/' }).Count -gt 0) {
      Fail 'hapPath contains duplicate or unsafe archive entries.'
    }
    foreach ($requiredEntry in @('module.json', 'pack.info', 'ets/modules.abc')) {
      $entry = @($entries | Where-Object { $_.FullName.Replace('\', '/') -ceq $requiredEntry })
      if ($entry.Count -ne 1 -or $entry[0].Length -le 0) {
        Fail "hapPath is missing a non-empty $requiredEntry."
      }
    }
    $moduleEntry = $archive.GetEntry('module.json')
    $moduleStream = $moduleEntry.Open()
    $moduleReader = [IO.StreamReader]::new($moduleStream, [Text.Encoding]::UTF8, $true)
    try {
      $module = $moduleReader.ReadToEnd() | ConvertFrom-Json
    } catch {
      Fail 'HAP module.json must be valid JSON.'
    } finally {
      $moduleReader.Dispose()
      $moduleStream.Dispose()
    }
    if ([string](Require-Property (Require-Property $module 'app') 'bundleName') -cne 'com.yuhaofeng.mih' -or
      [string](Require-Property (Require-Property $module 'module') 'name') -cne 'entry' -or
      [string](Require-Property $module.module 'mainElement') -cne 'EntryAbility' -or
      @((Require-Property $module.module 'abilities') | Where-Object {
          [string](Require-Property $_ 'name') -ceq 'EntryAbility'
        }).Count -ne 1) {
      Fail 'HAP module.json does not identify the production entry bundle/ability.'
    }
    $abis = @($entryNames | ForEach-Object {
        if ($_ -match '^libs/([^/]+)/[^/]+\.so$') { $matches[1] }
      } | Sort-Object -Unique)
    $moduleAbcStream = $archive.GetEntry('ets/modules.abc').Open()
    try {
      $moduleAbcSha256 = Get-StreamSha256 $moduleAbcStream
    } finally {
      $moduleAbcStream.Dispose()
    }
    return [pscustomobject]@{
      Abis = $abis
      EntryNames = $entryNames
      ModuleAbcSha256 = $moduleAbcSha256
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $file.Dispose()
  }
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
    'bounds' { @($Nodes | Where-Object { (Attr $_ 'bounds') -ceq $value }) }
    default { @() }
  })
  if ($matches.Count -ne 1) {
    Fail "state '$StateName' selector '$Selector' must identify exactly one captured subtree; found $($matches.Count)."
  }
  return $matches[0]
}

function Get-VisualRegionData(
  [string]$ScreenshotPath,
  [object]$Bounds,
  [string]$StateName,
  [string]$Selector
) {
  Add-Type -AssemblyName System.Drawing
  $bitmap = [Drawing.Bitmap]::new($ScreenshotPath)
  try {
    if ($Bounds.Left -lt 0 -or $Bounds.Top -lt 0 -or
      $Bounds.Right -gt $bitmap.Width -or $Bounds.Bottom -gt $bitmap.Height -or
      $Bounds.Width -le 0 -or $Bounds.Height -le 0) {
      Fail "state '$StateName' selector '$Selector' has invalid screenshot-region bounds."
    }
    $pixels = [byte[]]::new($Bounds.Width * $Bounds.Height * 3)
    $offset = 0
    [double]$lumaSum = 0
    [double]$lumaSquaredSum = 0
    for ($y = $Bounds.Top; $y -lt $Bounds.Bottom; $y++) {
      for ($x = $Bounds.Left; $x -lt $Bounds.Right; $x++) {
        $color = $bitmap.GetPixel($x, $y)
        $pixels[$offset++] = $color.R
        $pixels[$offset++] = $color.G
        $pixels[$offset++] = $color.B
        $luma = (0.2126 * $color.R) + (0.7152 * $color.G) + (0.0722 * $color.B)
        $lumaSum += $luma
        $lumaSquaredSum += $luma * $luma
      }
    }
    $pixelCount = $Bounds.Width * $Bounds.Height
    $mean = $lumaSum / $pixelCount
    $variance = [Math]::Max(0, ($lumaSquaredSum / $pixelCount) - ($mean * $mean))
    return [pscustomobject]@{
      Width = $Bounds.Width
      Height = $Bounds.Height
      Pixels = $pixels
      LumaStandardDeviation = [Math]::Sqrt($variance)
    }
  } finally {
    $bitmap.Dispose()
  }
}

function Get-VisualRegionMeanAbsoluteError([object]$Left, [object]$Right) {
  if ($Left.Width -ne $Right.Width -or $Left.Height -ne $Right.Height -or
    $Left.Pixels.Length -ne $Right.Pixels.Length) {
    return [double]::PositiveInfinity
  }
  [long]$difference = 0
  for ($index = 0; $index -lt $Left.Pixels.Length; $index++) {
    $difference += [Math]::Abs([int]$Left.Pixels[$index] - [int]$Right.Pixels[$index])
  }
  return $difference / [double]$Left.Pixels.Length
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
$resolvedGitRoot = Normalize-Text (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      rev-parse --show-toplevel 2>$null) -join "`n"
)
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($resolvedGitRoot).TrimEnd('\', '/') -cne $repositoryRoot) {
  Fail 'repositoryRoot must be the exact Git worktree root.'
}
$candidateDiffPath = [string](Require-Property $manifest 'candidateDiffPath')
Require-AbsoluteFile $candidateDiffPath 'candidateDiffPath'
if ((Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
  $candidateHash.ToLowerInvariant()) {
  Fail 'candidateDiffSha256 does not match candidateDiffPath.'
}
$commitSha = [string](Require-Property $manifest 'commitSha')
if ($commitSha -ne '' -and $commitSha -notmatch '^[0-9a-f]{40}$') { Fail 'commitSha must be empty or 40 hex characters.' }
$headSha = Normalize-Text (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      rev-parse HEAD 2>$null) -join "`n"
)
$statusText = Normalize-Text (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      status --porcelain=v1 --untracked-files=all 2>$null) -join "`n"
)
if ($commitSha -eq '') {
  if ($statusText -match '(?m)^\?\? ') {
    Fail 'an uncommitted evidence candidate must not contain untracked files outside the Git diff.'
  }
  $gitDiff = Normalize-Text (
    (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
        diff --binary HEAD -- 2>$null) -join "`n"
  )
} else {
  $resolvedCommit = Normalize-Text (
    (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
        rev-parse $commitSha 2>$null) -join "`n"
  )
  if ($LASTEXITCODE -ne 0 -or $resolvedCommit -cne $commitSha -or $headSha -cne $commitSha) {
    Fail 'commitSha must resolve to the captured worktree HEAD.'
  }
  $gitDiff = Normalize-Text (
    (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
        diff --binary "$commitSha^" $commitSha -- 2>$null) -join "`n"
  )
}
if ((Normalize-Text ([IO.File]::ReadAllText($candidateDiffPath))) -cne $gitDiff) {
  Fail 'candidateDiffPath is not the actual Git candidate diff.'
}
$candidateKind = if ($commitSha -eq '') { 'workingTree' } else { 'commit' }
$candidateIdentitySha256 = if ($candidateKind -eq 'workingTree') {
  Get-TextSha256 $gitDiff
} else {
  Get-TextSha256 $headSha
}

$hapPath = [string](Require-Property $manifest 'hapPath')
Require-AbsoluteFile $hapPath 'hapPath'
$canonicalHapPath = Join-Path $repositoryRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
if ([IO.Path]::GetFullPath($hapPath) -ine [IO.Path]::GetFullPath($canonicalHapPath)) {
  Fail 'hapPath must be the canonical HAP output of the bound repository.'
}
$hapHash = [string](Require-Property $manifest 'hapSha256')
if ($hapHash -notmatch '^[0-9a-f]{64}$') { Fail 'hapSha256 must be 64 hex characters.' }
$actualHapHash = (Get-FileHash -LiteralPath $hapPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHapHash -cne $hapHash) { Fail 'hapSha256 does not match hapPath.' }
$hapStructure = Get-HapStructure $hapPath
$buildProfilePath = Join-Path $repositoryRoot 'entry\build-profile.json5'
Require-AbsoluteFile $buildProfilePath 'entry/build-profile.json5'
$buildProfile = [IO.File]::ReadAllText($buildProfilePath)
$abiMatch = [regex]::Match(
  $buildProfile,
  '"abiFilters"\s*:\s*\[(?<abis>.*?)\]',
  [Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $abiMatch.Success) { Fail 'entry/build-profile.json5 must declare abiFilters.' }
$targetAbis = @([regex]::Matches($abiMatch.Groups['abis'].Value, '"([^"]+)"') |
    ForEach-Object { $_.Groups[1].Value })
if (($targetAbis -join ',') -cne 'arm64-v8a,x86_64' -or
  ($hapStructure.Abis -join ',') -cne ($targetAbis -join ',')) {
  Fail 'HAP ABI payloads must exactly match the arm64-v8a,x86_64 candidate profile.'
}
foreach ($abi in $targetAbis) {
  if ($hapStructure.EntryNames -cnotcontains "libs/$abi/libMNN.so") {
    Fail "HAP is missing the candidate runtime marker for ABI $abi."
  }
}
$buildReceiptPath = [string](Require-Property $manifest 'buildReceiptPath')
Require-AbsoluteFile $buildReceiptPath 'buildReceiptPath'
if ([IO.Path]::GetFullPath($buildReceiptPath) -ine [IO.Path]::GetFullPath("$hapPath.runtime-ui-build.json")) {
  Fail 'buildReceiptPath must be the canonical sidecar of hapPath.'
}
try {
  $buildReceipt = Get-Content -LiteralPath $buildReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json
} catch {
  Fail 'buildReceiptPath must contain valid UTF-8 JSON.'
}
$receiptWriterPath = Join-Path $repositoryRoot 'scripts\write-runtime-ui-build-receipt.ps1'
Require-AbsoluteFile $receiptWriterPath 'runtime UI build receipt writer'
if ([int](Require-Property $buildReceipt 'schemaVersion') -ne 1 -or
  [string](Require-Property $buildReceipt 'repositoryRoot') -cne $repositoryRoot -or
  [string](Require-Property $buildReceipt 'gitHead') -cne $headSha -or
  [string](Require-Property $buildReceipt 'gitStatusSha256') -cne (Get-TextSha256 $statusText) -or
  [string](Require-Property $buildReceipt 'candidateKind') -cne $candidateKind -or
  [string](Require-Property $buildReceipt 'candidateIdentitySha256') -cne $candidateIdentitySha256 -or
  [string](Require-Property $buildReceipt 'hapSha256') -cne $actualHapHash -or
  [string](Require-Property $buildReceipt 'moduleAbcSha256') -cne $hapStructure.ModuleAbcSha256 -or
  [string](Require-Property $buildReceipt 'buildProfileSha256') -cne
    (Get-FileHash -LiteralPath $buildProfilePath -Algorithm SHA256).Hash.ToLowerInvariant() -or
  [string](Require-Property $buildReceipt 'receiptWriterSha256') -cne
    (Get-FileHash -LiteralPath $receiptWriterPath -Algorithm SHA256).Hash.ToLowerInvariant() -or
  (@((Require-Property $buildReceipt 'abis')) -join ',') -cne ($targetAbis -join ',')) {
  Fail 'build receipt does not bind the HAP to the current candidate/HEAD/profile/ABI payload.'
}
$buildScriptPath = Join-Path $repositoryRoot 'scripts\build-hap.ps1'
Require-AbsoluteFile $buildScriptPath 'scripts/build-hap.ps1'
$tokens = $null
$parseErrors = $null
$buildAst = [Management.Automation.Language.Parser]::ParseFile(
  $buildScriptPath,
  [ref]$tokens,
  [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) { Fail 'scripts/build-hap.ps1 must parse cleanly.' }
$verifyCall = "& (Join-Path `$PSScriptRoot 'verify-ai-runtime-haps.ps1') -MainHapPath `$mainHap"
$receiptCall = "& (Join-Path `$PSScriptRoot 'write-runtime-ui-build-receipt.ps1') -HapPath `$mainHap"
$verifyStatements = @($buildAst.EndBlock.Statements | Where-Object {
    $_.Extent.Text.Replace("`r`n", "`n").Trim() -ceq $verifyCall
  })
$receiptStatements = @($buildAst.EndBlock.Statements | Where-Object {
    $_.Extent.Text.Replace("`r`n", "`n").Trim() -ceq $receiptCall
  })
if ($verifyStatements.Count -ne 1 -or $receiptStatements.Count -ne 1 -or
  $receiptStatements[0].Extent.StartOffset -le $verifyStatements[0].Extent.StartOffset) {
  Fail 'build-hap must write the runtime evidence receipt after successful HAP payload verification.'
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
$harnessPagePath = Join-Path $repositoryRoot 'entry\src\main\ets\pages\RuntimeHarnessPage.ets'
$entryAbilityPath = Join-Path $repositoryRoot 'entry\src\main\ets\entryability\EntryAbility.ets'
$hasHarnessPage = Test-Path -LiteralPath $harnessPagePath -PathType Leaf
$derivedSource = if ($hasHarnessPage -and $candidateKind -eq 'workingTree' -and
  $gitDiff -match '(?m)^\+\+\+ b/entry/src/main/ets/pages/RuntimeHarnessPage\.ets$') {
  'harness'
} else {
  'production'
}
if ($sourceKind -cne $derivedSource) {
  Fail 'source must be derived from the bound production or isolated harness candidate.'
}
$derivedFontScale = 1.0
if ($derivedSource -eq 'harness') {
  Require-AbsoluteFile $entryAbilityPath 'harness EntryAbility'
  $harnessPage = [IO.File]::ReadAllText($harnessPagePath)
  $entryAbility = [IO.File]::ReadAllText($entryAbilityPath)
  if ($harnessPage -notmatch '(?m)^[\t ]*(?:export[\t ]+)?struct[\t ]+RuntimeHarnessPage\b' -or
    $gitDiff -notmatch '(?m)^\+\+\+ b/entry/src/main/ets/entryability/EntryAbility\.ets$') {
    Fail 'harness source must contain the bound RuntimeHarnessPage and EntryAbility patch.'
  }
  if ($entryAbility -match '\.setFontSizeScale\(3\.2\)') { $derivedFontScale = 3.2 }
}
if ($fontScale -ne $derivedFontScale -or
  (($fontScale -eq 3.2 -or $routeName -eq '/custommodel/CustomModelMainActivity') -and
    $derivedSource -ne 'harness')) {
  Fail 'fontScale/hidden-route claims do not match the bound production or harness source.'
}
$displayDumpPath = [string](Require-Property $manifest 'displayDumpPath')
Require-AbsoluteFile $displayDumpPath 'displayDumpPath'
$displayDump = [IO.File]::ReadAllText($displayDumpPath)
$displayWidthPx = [int](Get-DisplayMetricValues $displayDump '(?m)^Width:\s+(\d+)\s*$' 'display width')
$displayHeightPx = [int](Get-DisplayMetricValues $displayDump '(?m)^Height:\s+(\d+)\s*$' 'display height')
$modeWidth = [int](Get-DisplayMetricValues `
    $displayDump `
    '(?m)^activeModes<id, W, H, RS>:\s+\d+,\s*(\d+),\s*\d+,\s*\d+\s*$' `
    'active-mode width')
$modeHeight = [int](Get-DisplayMetricValues `
    $displayDump `
    '(?m)^activeModes<id, W, H, RS>:\s+\d+,\s*\d+,\s*(\d+),\s*\d+\s*$' `
    'active-mode height')
$density = Get-DisplayMetricValues $displayDump '(?m)^Density:\s+([0-9.]+)\s*$' 'density'
$virtualPixelRatio = Get-DisplayMetricValues `
  $displayDump `
  '(?m)^VirtualPixelRatio:\s+([0-9.]+)\s*$' `
  'virtual pixel ratio'
$virtualWidth = Get-DisplayMetricValues $displayDump '(?m)^VirtualWidth:\s+(\d+)\s*$' 'virtual width'
$virtualHeight = Get-DisplayMetricValues $displayDump '(?m)^VirtualHeight:\s+(\d+)\s*$' 'virtual height'
if ($displayWidthPx -le 0 -or $displayHeightPx -le 0 -or $density -le 0 -or
  $modeWidth -ne $displayWidthPx -or $modeHeight -ne $displayHeightPx -or
  [Math]::Abs($density - $virtualPixelRatio) -gt 0.001 -or
  [Math]::Abs(($virtualWidth * $density) - $displayWidthPx) -gt 2 -or
  [Math]::Abs(($virtualHeight * $density) - $displayHeightPx) -gt 2 -or
  [double](Require-Property $manifest 'density') -ne $density) {
  Fail 'display dump dimensions/density are inconsistent with each other or the manifest.'
}
if ($displayWidthPx -ne 1320 -or $displayHeightPx -ne 2856 -or
  [Math]::Abs($density - 3.5) -gt 0.001 -or
  [Math]::Abs($virtualWidth - 377) -gt 0.001 -or
  [Math]::Abs($virtualHeight - 816) -gt 0.001) {
  Fail 'device evidence must come from the pinned API 24 emulator display profile.'
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
  $appNodes = @(Flatten-Nodes $appRoot[0])
  $routeRoot = @($appNodes | Where-Object { (Attr $_ 'key') -ceq $routeName })
  if ($routeRoot.Count -ne 1) {
    Fail "state '$name' does not bind routeName to the captured runtime root key."
  }
  $nodes = @(Flatten-Nodes $routeRoot[0])
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
  $routeBounds = Parse-Bounds (Attr $routeRoot[0] 'bounds')
  if ($null -eq $routeBounds -or $routeBounds.Width -le 0 -or $routeBounds.Height -le 0 -or
    $routeBounds.Left -lt $appBounds.Left -or $routeBounds.Top -lt $appBounds.Top -or
    $routeBounds.Right -gt $appBounds.Right -or $routeBounds.Bottom -gt $appBounds.Bottom) {
    Fail "state '$name' runtime route bounds are invalid or outside the application root."
  }
  if ($bottomInsetPx -ne ($displayHeightPx - $routeBounds.Bottom)) {
    Fail "state '$name' bottomInsetPx does not match the captured display/runtime-route bounds."
  }
  $clickableBounds = [Collections.Generic.List[object]]::new()
  foreach ($node in $nodes | Where-Object { Is-Visible $_ }) {
    $boundsText = Attr $node 'bounds'
    if ([string]::IsNullOrWhiteSpace($boundsText)) { continue }
    $bounds = Parse-Bounds $boundsText
    if ($null -eq $bounds -or $bounds.Width -lt 0 -or $bounds.Height -lt 0 -or
      $bounds.Left -lt $routeBounds.Left -or $bounds.Top -lt $routeBounds.Top -or
      $bounds.Right -gt $routeBounds.Right -or $bounds.Bottom -gt $routeBounds.Bottom) {
      Fail "state '$name' contains visible bounds outside the runtime route area."
    }
    $label = Node-Label $node
    if (-not [string]::IsNullOrWhiteSpace($label) -and ($bounds.Width -le 0 -or $bounds.Height -le 0)) {
      Fail "state '$name' contains a hidden/clipped label."
    }
    if ((Attr $node 'clickable') -eq 'true') {
      if (($bounds.Width / $density) -lt $minTargetVp -or ($bounds.Height / $density) -lt $minTargetVp) {
        Fail "state '$name' contains an undersized clickable target."
      }
      if ($bounds.Bottom -gt $routeBounds.Bottom) {
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
  $preservedVisualRegions = @{}
  foreach ($selector in $preservedSelectors) {
    $preservedNode = Get-PreservationNode $nodes ([string]$selector) $name
    $preservedHashes[[string]$selector] = Get-PreservationHash $preservedNode
    $preservedBounds = Parse-Bounds (Attr $preservedNode 'bounds')
    if ($null -eq $preservedBounds) {
      Fail "state '$name' selector '$selector' has invalid visual bounds."
    }
    $visualRegion = Get-VisualRegionData $screenshotPath $preservedBounds $name ([string]$selector)
    if ($visualRegion.LumaStandardDeviation -lt 2.0) {
      Fail "state '$name' selector '$selector' does not contain a non-empty visual result."
    }
    $preservedVisualRegions[[string]$selector] = $visualRegion
  }
  $stateData[$name] = [pscustomobject]@{
    PreserveFrom = $preservedFrom
    Selectors = $preservedSelectors
    Hashes = $preservedHashes
    VisualRegions = $preservedVisualRegions
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
    $visualMae = Get-VisualRegionMeanAbsoluteError `
      $stateData[$name].VisualRegions[[string]$selector] `
      $stateData[$reference].VisualRegions[[string]$selector]
    if ($visualMae -gt 2.0) {
      Fail "state '$name' changed preserved screenshot pixels for '$selector' (MAE=$visualMae)."
    }
  }
}

Write-Output 'Runtime UI evidence manifest passed.'
