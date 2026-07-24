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

function Get-BytesSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
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
    origBounds = $Bounds
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

function Write-Jpeg(
  [string]$Path,
  [int]$Width = 1320,
  [int]$Height = 2856,
  [string]$Variant = 'initial'
) {
  Add-Type -AssemblyName System.Drawing
  $bitmap = [Drawing.Bitmap]::new($Width, $Height)
  try {
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([Drawing.Color]::White)
      if ($Width -eq 1320 -and $Height -eq 2856 -and $Variant -ne 'blank') {
        $primary = if ($Variant -eq 'changed') {
          [Drawing.Color]::FromArgb(255, 210, 55, 70)
        } else {
          [Drawing.Color]::FromArgb(255, 25, 110, 220)
        }
        $secondary = if ($Variant -eq 'changed') {
          [Drawing.Color]::FromArgb(255, 245, 190, 35)
        } else {
          [Drawing.Color]::FromArgb(255, 45, 205, 130)
        }
        $graphics.FillRectangle([Drawing.SolidBrush]::new($primary), 70, 350, 700, 700)
        for ($offset = 0; $offset -lt 700; $offset += 35) {
          $graphics.FillRectangle(
            [Drawing.SolidBrush]::new($secondary),
            70 + $offset,
            350 + ((3 * $offset) % 665),
            35,
            35
          )
        }
      }
    } finally {
      $graphics.Dispose()
    }
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Jpeg)
  } finally {
    $bitmap.Dispose()
  }
}

function Write-Hap(
  [string]$Path,
  [string[]]$Abis = @('arm64-v8a', 'x86_64')
) {
  Add-Type -AssemblyName System.IO.Compression
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
  $moduleJson = [ordered]@{
    app = [ordered]@{ bundleName = 'com.yuhaofeng.mih' }
    module = [ordered]@{
      name = 'entry'
      mainElement = 'EntryAbility'
      abilities = @([ordered]@{ name = 'EntryAbility' })
    }
  } | ConvertTo-Json -Depth 10 -Compress
  $entries = [ordered]@{
    'module.json' = $moduleJson
    'pack.info' = '{"summary":{"app":{"bundleName":"com.yuhaofeng.mih"}}}'
    'ets/modules.abc' = 'candidate abc payload'
  }
  foreach ($abi in $Abis) { $entries["libs/$abi/libMNN.so"] = "$abi candidate payload" }
  $file = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
  $archive = $null
  try {
    $archive = [IO.Compression.ZipArchive]::new(
      $file,
      [IO.Compression.ZipArchiveMode]::Create,
      $false
    )
    foreach ($entryName in $entries.Keys) {
      $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
      $stream = $entry.Open()
      try {
        $bytes = $utf8.GetBytes([string]$entries[$entryName])
        $stream.Write($bytes, 0, $bytes.Length)
      } finally {
        $stream.Dispose()
      }
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $file.Dispose()
  }
}

function Write-DisplayDump([string]$Path, [double]$Density = 3.5) {
  $virtualWidth = [int][Math]::Round(1320 / $Density)
  $virtualHeight = [int][Math]::Round(2856 / $Density)
  $text = @"
---------------- Screen ID: 0 ----------------
activeModes<id, W, H, RS>:    0, 1320, 2856, 60
[SCREEN INFO]
VirtualWidth:                 $virtualWidth
VirtualHeight:                $virtualHeight
VirtualPixelRatio:            $Density
[SCREEN PROPERTY]
Density:                      $Density
DensityInCurResolution:       $Density
VirtualPixelRatio:            $Density
Bounds<L,T,W,H>:              0, 0, 1320, 2856,
---------------- Display ID: 0 ----------------
[DISPLAY INFO]
Width:                        1320
Height:                       2856
"@
  [IO.File]::WriteAllText($Path, $text, $utf8)
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
  $output = @(& git -c core.autocrlf=false -c core.safecrlf=false -C $RepositoryRoot @Arguments 2>$null)
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
  Invoke-Git $repositoryRoot @('config', 'core.autocrlf', 'true') | Out-Null
  Invoke-Git $repositoryRoot @('config', 'user.email', 'runtime-fixture@example.invalid') | Out-Null
  Invoke-Git $repositoryRoot @('config', 'user.name', 'Runtime Fixture') | Out-Null
  [IO.File]::WriteAllText((Join-Path $repositoryRoot '.gitignore'), "entry/build/`n", $utf8)
  $candidateFile = Join-Path $repositoryRoot 'entry/src/main/ets/pages/Candidate.ets'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($candidateFile)) | Out-Null
  [IO.File]::WriteAllText($candidateFile, "baseline`n", $utf8)
  $buildProfilePath = Join-Path $repositoryRoot 'entry/build-profile.json5'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($buildProfilePath)) | Out-Null
  [IO.File]::WriteAllText(
    $buildProfilePath,
    '{"buildOption":{"externalNativeOptions":{"abiFilters":["arm64-v8a","x86_64"]}}}',
    $utf8
  )
  $buildScriptPath = Join-Path $repositoryRoot 'scripts/build-hap.ps1'
  $receiptWriterPath = Join-Path $repositoryRoot 'scripts/write-runtime-ui-build-receipt.ps1'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($buildScriptPath)) | Out-Null
  [IO.File]::WriteAllText(
    $buildScriptPath,
    @'
$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') -MainHapPath $mainHap
& (Join-Path $PSScriptRoot 'write-runtime-ui-build-receipt.ps1') -HapPath $mainHap
'@,
    $utf8
  )
  [IO.File]::Copy(
    (Join-Path $PSScriptRoot 'write-runtime-ui-build-receipt.ps1'),
    $receiptWriterPath
  )
  Invoke-Git $repositoryRoot @(
    'add',
    '--',
    '.gitignore',
    'entry/src/main/ets/pages/Candidate.ets',
    'entry/build-profile.json5',
    'scripts/build-hap.ps1',
    'scripts/write-runtime-ui-build-receipt.ps1'
  ) | Out-Null
  Invoke-Git $repositoryRoot @('commit', '--quiet', '-m', 'fixture baseline') | Out-Null
  [IO.File]::WriteAllText($candidateFile, "candidate change`n", $utf8)

  $candidateDiffPath = Join-Path $Root 'candidate.diff'
  [IO.File]::WriteAllText(
    $candidateDiffPath,
    (Invoke-Git $repositoryRoot @('diff', '--binary', 'HEAD', '--')),
    $utf8
  )
  $candidateHash = (Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $hap = Join-Path $repositoryRoot 'entry/build/default/outputs/default/entry-default-unsigned.hap'
  $shot = Join-Path $Root 'initial.jpeg'
  $layoutPath = Join-Path $Root 'initial.json'
  $aa = Join-Path $Root 'aa-dump.txt'
  $displayDumpPath = Join-Path $Root 'display-manager.txt'
  $buildReceiptPath = "$hap.runtime-ui-build.json"
  $permissionBeforePath = Join-Path $Root 'permission-before.json'
  $permissionAfterPath = Join-Path $Root 'permission-after.json'
  Write-Hap $hap
  Write-Jpeg $shot
  Write-DisplayDump $displayDumpPath
  [IO.File]::WriteAllText(
    $aa,
    'app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND',
    $utf8
  )
  $hapHash = (Get-FileHash -LiteralPath $hap -Algorithm SHA256).Hash.ToLowerInvariant()
  & $receiptWriterPath -HapPath $hap | Out-Null
  if (-not [IO.File]::Exists($buildReceiptPath)) {
    throw 'Fixture build receipt writer did not create the expected receipt.'
  }
  Write-PermissionProof $permissionBeforePath -1 -1
  Write-PermissionProof $permissionAfterPath 0 -1

  $displayAttrs = Attrs 'root' '[0,0][1320,2856]'
  $appAttrs = Attrs 'root' '[0,137][1320,2856]'
  $appAttrs.abilityName = 'EntryAbility'
  $appAttrs.bundleName = 'com.yuhaofeng.mih'
  $appAttrs.pagePath = 'pages/FeatureRuntimePage'
  $routeAttrs = Attrs 'Stack' '[0,137][1320,2758]' '' 'false' 'false' '/imageobject/ObjectPhotoActivity'
  $imageAttrs = Attrs 'Image' '[70,350][770,1050]'
  $imageAttrs.backgroundImage = 'empty source'
  $layout = [ordered]@{
    attributes = $displayAttrs
    children = @(
      [ordered]@{
        attributes = $appAttrs
        children = @(
          [ordered]@{
            attributes = $routeAttrs
            children = @(
              [ordered]@{
                attributes = (Attrs 'Scroll' '[0,137][1320,2758]' '' 'false' 'true')
                children = @(
                  [ordered]@{ attributes = $imageAttrs; children = @() },
                  [ordered]@{ attributes = (Attrs 'Text' '[70,1120][1250,1300]' 'Initial'); children = @() },
                  [ordered]@{ attributes = (Attrs 'Button' '[70,2100][630,2280]' 'Retry' 'true'); children = @() },
                  [ordered]@{ attributes = (Attrs 'Button' '[700,2550][1260,2750]' 'Settings' 'true'); children = @() }
                )
              }
            )
          }
        )
      }
    )
  }
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
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
    density = 3.5
    displayDumpPath = $displayDumpPath
    buildReceiptPath = $buildReceiptPath
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
        bottomInsetPx = 98
        preservedBoundsHashFrom = ''
        preservedNodeSelectors = @('bounds:[70,350][770,1050]')
      }
    )
  }
  $manifestPath = Join-Path $Root 'manifest.json'
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  return $manifestPath
}

function Convert-FixtureToNestedProject([string]$ManifestPath) {
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  $gitRoot = [string]$manifest.repositoryRoot
  $projectName = 'Mindspore_inhand_HarmonyOS'
  $projectRoot = Join-Path $gitRoot $projectName
  Invoke-Git $gitRoot @('restore', '--', 'entry/src/main/ets/pages/Candidate.ets') | Out-Null
  [IO.File]::WriteAllText((Join-Path $gitRoot '.gitignore'), "**/entry/build/`n", $utf8)
  [IO.Directory]::CreateDirectory($projectRoot) | Out-Null
  Invoke-Git $gitRoot @('mv', 'entry', 'scripts', $projectName) | Out-Null
  Invoke-Git $gitRoot @('add', '--', '.gitignore') | Out-Null
  Invoke-Git $gitRoot @('commit', '--quiet', '-m', 'nest fixture project') | Out-Null

  $candidateFile = Join-Path $projectRoot 'entry/src/main/ets/pages/Candidate.ets'
  [IO.File]::WriteAllText($candidateFile, "candidate change`n", $utf8)
  $candidateDiffPath = [string]$manifest.candidateDiffPath
  [IO.File]::WriteAllText(
    $candidateDiffPath,
    (Invoke-Git $projectRoot @('diff', '--binary', 'HEAD', '--')),
    $utf8
  )
  $hapPath = Join-Path $projectRoot 'entry/build/default/outputs/default/entry-default-unsigned.hap'
  Write-Hap $hapPath
  $receiptWriterPath = Join-Path $projectRoot 'scripts/write-runtime-ui-build-receipt.ps1'
  & $receiptWriterPath -HapPath $hapPath | Out-Null

  $manifest.repositoryRoot = $projectRoot
  $manifest.candidateDiffSha256 =
    (Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest.hapPath = $hapPath
  $manifest.hapSha256 =
    (Get-FileHash -LiteralPath $hapPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest.buildReceiptPath = "$hapPath.runtime-ui-build.json"
  [IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  return $ManifestPath
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
  $nestedValidPath = Convert-FixtureToNestedProject (
    New-Fixture (Join-Path $tempRoot 'nested-valid')
  )
  & $guardPath -ManifestPath $nestedValidPath | Out-Null
  $nestedManifest = Get-Content -LiteralPath $nestedValidPath -Raw -Encoding utf8 | ConvertFrom-Json
  $nestedManifest.repositoryRoot = Split-Path -Parent ([string]$nestedManifest.repositoryRoot)
  [IO.File]::WriteAllText($nestedValidPath, ($nestedManifest | ConvertTo-Json -Depth 20), $utf8)
  $nestedWrongRootRejected = $false
  try { & $guardPath -ManifestPath $nestedValidPath | Out-Null } catch { $nestedWrongRootRejected = $true }
  if (-not $nestedWrongRootRejected) {
    throw 'Runtime evidence guard accepted a nested-project manifest bound to the Git root.'
  }

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
  Assert-Rejected 'coordinated-environment-claims' {
    param($m, $l, $r)
    $m.source = 'harness'
    $m.fontScale = 3.2
    $m.density = 0.5
    Write-DisplayDump ([string]$m.displayDumpPath) 0.5
  }
  Assert-Rejected 'coordinated-display-density-claims' {
    param($m, $l, $r)
    $m.density = 0.5
    Write-DisplayDump ([string]$m.displayDumpPath) 0.5
  }
  Assert-Rejected 'coordinated-fake-hap' {
    param($m, $l, $r)
    [IO.File]::WriteAllBytes([string]$m.hapPath, [byte[]](5, 6, 7, 8))
    $m.hapSha256 =
      (Get-FileHash -LiteralPath ([string]$m.hapPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  Assert-Rejected 'coordinated-wrong-hap-abi' {
    param($m, $l, $r)
    Write-Hap ([string]$m.hapPath) @('arm64-v8a')
    $newHash = (Get-FileHash -LiteralPath ([string]$m.hapPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    $m.hapSha256 = $newHash
    $receipt = Get-Content -LiteralPath ([string]$m.buildReceiptPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $receipt.hapSha256 = $newHash
    $receipt.abis = @('arm64-v8a')
    [IO.File]::WriteAllText(
      [string]$m.buildReceiptPath,
      ($receipt | ConvertTo-Json -Depth 10),
      $utf8
    )
  }
  Assert-Rejected 'build-receipt-candidate-identity' {
    param($m, $l, $r)
    $receipt = Get-Content -LiteralPath ([string]$m.buildReceiptPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $receipt.candidateIdentitySha256 = ('0' * 64)
    [IO.File]::WriteAllText(
      [string]$m.buildReceiptPath,
      ($receipt | ConvertTo-Json -Depth 10),
      $utf8
    )
  }
  Assert-Rejected 'build-receipt-status-proof' {
    param($m, $l, $r)
    $receipt = Get-Content -LiteralPath ([string]$m.buildReceiptPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $receipt.gitStatusSha256 = ('0' * 64)
    [IO.File]::WriteAllText(
      [string]$m.buildReceiptPath,
      ($receipt | ConvertTo-Json -Depth 10),
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
    Write-Jpeg ([string]$m.states[0].screenshot) 1321 2856
  }
  Assert-Rejected 'display-layout-mismatch' {
    param($m, $l, $r)
    $l.attributes.bounds = '[0,0][1321,2856]'
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
    $l.children[0].children[0].children[0].children[2].attributes.clickable = 'false'
  }
  Assert-Rejected 'min-target' { param($m, $l, $r) $m.states[0].minTargetVp = 43 }
  Assert-Rejected 'min-primary' { param($m, $l, $r) $m.states[0].minPrimaryTargetVp = 47 }
  Assert-Rejected 'undersized-target' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].children[2].attributes.bounds = '[70,2100][210,2240]'
    $l.children[0].children[0].children[0].children[2].attributes.origBounds = '[70,2100][210,2240]'
  }
  Assert-Rejected 'clipped-required-action-orig-bounds' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].children[2].attributes.origBounds = '[70,2100][700,2280]'
  }
  Assert-Rejected 'outside-app' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].children[1].attributes.bounds = '[-1,1120][1250,1300]'
  }
  Assert-Rejected 'bottom-inset-zero' { param($m, $l, $r) $m.states[0].bottomInsetPx = 0 }
  Assert-Rejected 'bottom-inset-mismatch' { param($m, $l, $r) $m.states[0].bottomInsetPx = 99 }
  Assert-Rejected 'overlap-required-actions' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].children[3].attributes.bounds = '[400,2100][960,2280]'
  }
  Assert-Rejected 'overlap-unlisted-action' {
    param($m, $l, $r)
    $extra = [pscustomobject]@{
      attributes = (Attrs 'Button' '[400,2100][960,2280]' 'Unlisted' 'true')
      children = @()
    }
    $l.children[0].children[0].children[0].children += $extra
  }
  Assert-Rejected 'fixed-route-switch' {
    param($m, $l, $r)
    $m.routeName = '/imageobject/ObjectCameraActivity'
    $l.children[0].children[0].attributes.key = '/imageobject/ObjectCameraActivity'
    $l.children[0].children[0].children[0].children[1].attributes.text = 'Switch camera'
    $l.children[0].children[0].children[0].children[1].attributes.originalText = 'Switch camera'
  }
  Assert-Rejected 'preservation-selector' {
    param($m, $l, $r)
    $m.states[0].preservedNodeSelectors = @('type:Button')
  }
  Assert-Rejected 'preservation-empty-pixels' {
    param($m, $l, $r)
    Write-Jpeg ([string]$m.states[0].screenshot) 1320 2856 'blank'
  }
  Assert-Rejected 'preservation-subtree' {
    param($m, $l, $r)
    $secondLayout = Join-Path $r 'failure.json'
    $secondShot = Join-Path $r 'failure.jpeg'
    Write-Jpeg $secondShot 1320 2856 'changed'
    $copy = $l | ConvertTo-Json -Depth 20 | ConvertFrom-Json
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
