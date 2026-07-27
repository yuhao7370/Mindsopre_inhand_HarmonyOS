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

function Test-PathInside([string]$Path, [string]$Directory) {
  $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $resolvedDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd('\', '/')
  return $resolvedPath.StartsWith($resolvedDirectory + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)
}

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
}

function Convert-Task14MediaListings([object[]]$Events, [string]$Phase, [string[]]$TargetPrefix) {
  $root = '/storage/media/100/local/files/Photo'
  $entries = @()
  foreach ($event in $Events) {
    $directory = [string](Require-Property $event 'mediaDirectory')
    $depth = [int](Require-Property $event 'depth')
    if ($directory -cne $root -and -not $directory.StartsWith("$root/",
        [StringComparison]::Ordinal)) {
      Fail "task 14 $Phase media listing directory is outside Photo."
    }
    $relative = $directory.Substring($root.Length).Trim('/')
    $actualDepth = if ($relative.Length -eq 0) { 0 } else { @($relative -split '/').Count }
    $expectedArgv = $TargetPrefix + @('shell', 'mediatool', 'ls', '-l', $directory)
    if ($depth -lt 0 -or $depth -gt 2 -or $actualDepth -ne $depth -or
      [string](Require-Property $event 'type') -cne "source.media.$Phase.level$depth" -or
      (@($event.argv) -join "`0") -cne (@($expectedArgv) -join "`0")) {
      Fail "task 14 $Phase media listing directory/depth/argv is invalid."
    }
    foreach ($line in @(([string](Require-Property $event 'stdout')) -split "`r?`n")) {
      $trimmed = $line.Trim()
      if ($trimmed.Length -eq 0 -or $trimmed -match '^(No Error|total\s+\d+)') { continue }
      $name = @($trimmed -split '\s+')[-1].Trim('"')
      if ($name.StartsWith('/') -or $name.Contains('/') -or $name.Contains('\') -or
        $name -match '^[.]+$' -or $name.Contains(':')) {
        Fail "task 14 $Phase mediatool listing must expose a basename, not a synthetic path."
      }
      $size = 0L
      foreach ($token in @($trimmed -split '\s+')) {
        $parsed = 0L
        if ([long]::TryParse($token, [ref]$parsed)) { $size = $parsed }
      }
      $entries += [pscustomobject]@{
        Path = "$($directory.TrimEnd('/'))/$name"
        Size = $size
        IsDirectory = $trimmed.StartsWith('d')
        EventId = [string](Require-Property $event 'eventId')
      }
    }
  }
  return $entries
}

function Convert-Task14MediaSnapshots(
  [object[]]$Events,
  [string]$Phase,
  [string[]]$TargetPrefix
) {
  $root = '/storage/media/100/local/files/Photo'
  $groups = [Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($event in $Events) {
    if ([string]$event.type -ceq "source.media.$Phase.level0") {
      if ($null -ne $current) { $groups.Add($current.ToArray()) }
      $current = [Collections.Generic.List[object]]::new()
    }
    if ($null -eq $current) {
      Fail "task 14 $Phase media traversal does not begin at level0."
    }
    $current.Add($event)
  }
  if ($null -ne $current) { $groups.Add($current.ToArray()) }
  $snapshots = @()
  for ($snapshotIndex = 0; $snapshotIndex -lt $groups.Count; $snapshotIndex++) {
    $snapshotEvents = @($groups[$snapshotIndex])
    for ($eventIndex = 1; $eventIndex -lt $snapshotEvents.Count; $eventIndex++) {
      if ([int]$snapshotEvents[$eventIndex].sequence -ne
        ([int]$snapshotEvents[$eventIndex - 1].sequence + 1)) {
        Fail "task 14 $Phase media snapshot $snapshotIndex is not transcript-contiguous."
      }
    }
    if ($snapshotIndex -gt 0) {
      $previousEvents = @($groups[$snapshotIndex - 1])
      $settleTicks =
        [long]$snapshotEvents[0].startedMonotonicTicks -
        [long]$previousEvents[-1].endedMonotonicTicks
      if ($settleTicks -lt [long]([Diagnostics.Stopwatch]::Frequency * 0.4)) {
        Fail "task 14 $Phase media snapshots lack the signed settle interval."
      }
    }
    $entries = @(Convert-Task14MediaListings $snapshotEvents $Phase $TargetPrefix)
    $expectedDirectories = @($root)
    for ($depth = 0; $depth -le 2; $depth++) {
      $levelEvents = @($snapshotEvents | Where-Object {
          [string]$_.type -ceq "source.media.$Phase.level$depth"
        })
      $actualDirectories = @($levelEvents | ForEach-Object {
          [string]$_.mediaDirectory
        } | Sort-Object -Unique)
      $expectedSorted = @($expectedDirectories | Sort-Object -Unique)
      if ($levelEvents.Count -ne $expectedSorted.Count -or
        ($actualDirectories -join "`0") -cne ($expectedSorted -join "`0")) {
        Fail "task 14 $Phase media snapshot $snapshotIndex is not a complete traversal."
      }
      $expectedDirectories = if ($depth -lt 2) {
        @($entries | Where-Object {
            $_.IsDirectory -and
            @([string]$_.Path.Substring($root.Length).Trim('/') -split '/').Count -eq
              ($depth + 1)
          } | ForEach-Object { [string]$_.Path } | Sort-Object -Unique)
      } else {
        @()
      }
    }
    $snapshots += [pscustomobject]@{
      Index = $snapshotIndex
      Events = $snapshotEvents
      Entries = $entries
    }
  }
  return $snapshots
}

function Assert-Task14CaptureEvent(
  [object]$Capture,
  [hashtable]$EventsById,
  [string[]]$TargetPrefix,
  [string]$ManifestDirectory
) {
  $captureType = [string](Require-Property $Capture 'type')
  $isPicker = $captureType -ceq 'picker.capture'
  if (-not $isPicker -and $captureType -cne 'capture') {
    Fail 'task 14 capture event has an unreviewed type.'
  }
  $sourceIds = @((Require-Property $Capture 'sourceCommandEventIds'))
  $expectedTypes = if ($isPicker) {
    @(
      'source.picker.layout-attempt', 'source.picker.screen',
      'source.picker.recv-layout-attempt', 'source.picker.recv-screen',
      'source.picker.foreground-aa'
    )
  } else {
    @(
      'source.capture.layout', 'source.capture.screen',
      'source.capture.recv-layout', 'source.capture.recv-screen',
      'source.capture.foreground-aa', 'source.capture.display'
    )
  }
  if ($sourceIds.Count -ne $expectedTypes.Count -or
    @($sourceIds | Sort-Object -Unique).Count -ne $sourceIds.Count) {
    Fail 'task 14 capture source-command list is incomplete or duplicated.'
  }
  $sources = @()
  for ($index = 0; $index -lt $sourceIds.Count; $index++) {
    $sourceId = [string]$sourceIds[$index]
    if (-not $EventsById.ContainsKey($sourceId)) {
      Fail "task 14 capture source command '$sourceId' is missing."
    }
    $source = $EventsById[$sourceId]
    if ([string](Require-Property $source 'type') -cne $expectedTypes[$index] -or
      [string](Require-Property $source 'stateName') -cne [string]$Capture.stateName -or
      [int](Require-Property $source 'sequence') -ge [int]$Capture.sequence -or
      ($index -gt 0 -and
        [int]$source.sequence -le [int]$sources[$index - 1].sequence)) {
      Fail 'task 14 capture source commands have wrong type/state/order.'
    }
    $sources += $source
  }
  $dumpArgv = @($sources[0].argv)
  $remoteLayout = [string]$dumpArgv[-1]
  if (-not $remoteLayout.EndsWith('.json', [StringComparison]::Ordinal)) {
    Fail 'task 14 capture dumpLayout target is invalid.'
  }
  $remoteBase = $remoteLayout.Substring(0, $remoteLayout.Length - 5)
  $layoutDestination = [string]@($sources[2].argv)[-1]
  $rawScreenshotPath = [string](Require-Property $Capture 'rawScreenshotPath')
  $captureName = [string](Require-Property $Capture 'captureName')
  $captureRoot = Join-Path $ManifestDirectory 'runner-captures'
  $expectedStem = if ($isPicker) { 'picker-intermediate' } else { $captureName }
  $expectedLocalPaths = @{
    layout = Join-Path $captureRoot "$expectedStem.json"
    raw = Join-Path $captureRoot "$expectedStem.png"
    jpeg = Join-Path $captureRoot "$expectedStem.jpeg"
    aa = Join-Path $captureRoot "$expectedStem-aa.txt"
  }
  if (-not $remoteBase.StartsWith(
      "/data/local/tmp/task14-$([string]$Capture.runId)-",
      [StringComparison]::Ordinal
    ) -or
    [IO.Path]::GetFullPath($layoutDestination) -ine
      [IO.Path]::GetFullPath([string]$expectedLocalPaths.layout) -or
    [IO.Path]::GetFullPath($rawScreenshotPath) -ine
      [IO.Path]::GetFullPath([string]$expectedLocalPaths.raw) -or
    [IO.Path]::GetFullPath([string]$Capture.screenshotPath) -ine
      [IO.Path]::GetFullPath([string]$expectedLocalPaths.jpeg) -or
    [IO.Path]::GetFullPath([string]$Capture.foregroundAaPath) -ine
      [IO.Path]::GetFullPath([string]$expectedLocalPaths.aa)) {
    Fail 'task 14 capture paths are not the runner-owned capture outputs.'
  }
  $expectedArgv = @(
    ($TargetPrefix + @('shell', 'uitest', 'dumpLayout', '-p', "$remoteBase.json")),
    ($TargetPrefix + @('shell', 'uitest', 'screenCap', '-p', "$remoteBase.png")),
    ($TargetPrefix + @('file', 'recv', "$remoteBase.json", $layoutDestination)),
    ($TargetPrefix + @('file', 'recv', "$remoteBase.png", $rawScreenshotPath)),
    ($TargetPrefix + @('shell', 'aa', 'dump', '-a'))
  )
  if (-not $isPicker) {
    $expectedArgv += ,($TargetPrefix + @(
        'shell', 'hidumper', '-s', 'DisplayManagerService', '-a', '-a'
      ))
  }
  for ($index = 0; $index -lt $sources.Count; $index++) {
    if ((@($sources[$index].argv) -join "`0") -cne
      (@($expectedArgv[$index]) -join "`0")) {
      Fail 'task 14 capture source command argv is not exact.'
    }
    if ([bool](Require-Property $sources[$index] 'timedOut') -or
      [int](Require-Property $sources[$index] 'timeoutMilliseconds') -le 0 -or
      (-not $isPicker -and [int](Require-Property $sources[$index] 'exitCode') -ne 0) -or
      ($isPicker -and $index -notin @(0, 2) -and
        [int](Require-Property $sources[$index] 'exitCode') -ne 0)) {
      Fail 'task 14 capture source command outcome is invalid.'
    }
  }
  foreach ($field in @('rawScreenshot', 'screenshot', 'foregroundAa')) {
    $path = [string](Require-Property $Capture "${field}Path")
    Require-AbsoluteFile $path "task 14 capture $field"
    if (-not (Test-PathInside $path $ManifestDirectory) -or
      [string](Require-Property $Capture "${field}Sha256") -cne
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()) {
      Fail "task 14 capture $field file/hash is unbound."
    }
  }
  try {
    Add-Type -AssemblyName System.Drawing
    $rawImage = [Drawing.Image]::FromFile([string]$Capture.rawScreenshotPath)
    $jpegImage = [Drawing.Image]::FromFile([string]$Capture.screenshotPath)
    $reencoded = [IO.MemoryStream]::new()
    try {
      if ($rawImage.Width -ne $jpegImage.Width -or $rawImage.Height -ne $jpegImage.Height -or
        $rawImage.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
        $jpegImage.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Jpeg.Guid) {
        Fail 'task 14 capture JPEG is not the same-size decoded screen capture.'
      }
      $rawImage.Save($reencoded, [Drawing.Imaging.ImageFormat]::Jpeg)
      if ((Get-BytesSha256 $reencoded.ToArray()) -cne [string]$Capture.screenshotSha256) {
        Fail 'task 14 capture JPEG is not the runner conversion of its signed raw PNG.'
      }
    } finally {
      $reencoded.Dispose()
      $rawImage.Dispose()
      $jpegImage.Dispose()
    }
  } catch {
    Fail 'task 14 capture image pair is not decodable.'
  }
  if ([IO.Path]::GetFullPath($rawScreenshotPath) -ine
    [IO.Path]::GetFullPath([string]@($sources[3].argv)[-1]) -or
    [IO.File]::ReadAllText([string]$Capture.foregroundAaPath) -cne [string]$sources[4].stdout) {
    Fail 'task 14 capture received screenshot/foreground files do not match source commands.'
  }
  if ($isPicker) {
    $outcomePath = [string](Require-Property $Capture 'layoutDumpOutcomePath')
    Require-AbsoluteFile $outcomePath 'task 14 picker dump outcome'
    $expectedOutcome =
      "dumpExitCode=$($sources[0].exitCode)`ndumpStdout=$($sources[0].stdout)`n" +
      "dumpStderr=$($sources[0].stderr)`nrecvExitCode=$($sources[2].exitCode)`n" +
      "recvStdout=$($sources[2].stdout)`nrecvStderr=$($sources[2].stderr)`n"
    $expectedOutcomePath = Join-Path $captureRoot 'picker-intermediate-dump-outcome.txt'
    if ([IO.Path]::GetFullPath($outcomePath) -ine
        [IO.Path]::GetFullPath($expectedOutcomePath) -or
      -not (Test-PathInside $outcomePath $ManifestDirectory) -or
      [string](Require-Property $Capture 'layoutDumpOutcomeSha256') -cne
        (Get-FileHash -LiteralPath $outcomePath -Algorithm SHA256).Hash.ToLowerInvariant() -or
      (Normalize-Text ([IO.File]::ReadAllText($outcomePath))) -cne
        (Normalize-Text $expectedOutcome)) {
      Fail 'task 14 picker dump outcome is not derived from signed source commands.'
    }
    $layoutAvailable = [bool](Require-Property $Capture 'layoutAvailable')
    $layoutExists = [IO.File]::Exists($layoutDestination)
    $layoutNonEmpty = $layoutExists -and ([IO.FileInfo]$layoutDestination).Length -gt 0
    $sourceProvesUnavailable =
      [int]$sources[0].exitCode -ne 0 -or [int]$sources[2].exitCode -ne 0 -or
      [string]$sources[0].stdout -match '(?i)DumpLayout failed:Get window nodes failed' -or
      -not $layoutNonEmpty
    if ($layoutAvailable) {
      $layoutPath = [string](Require-Property $Capture 'layoutPath')
      Require-AbsoluteFile $layoutPath 'task 14 picker layout'
      if ([IO.Path]::GetFullPath($layoutPath) -ine [IO.Path]::GetFullPath($layoutDestination) -or
        [string](Require-Property $Capture 'layoutSha256') -cne
          (Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
        Fail 'task 14 picker available layout is not bound to recv output.'
      }
    } elseif ([string](Require-Property $Capture 'layoutPath') -ne '' -or
      [string](Require-Property $Capture 'layoutSha256') -ne '' -or
      -not $sourceProvesUnavailable) {
      Fail 'task 14 picker unavailable layout is not proven by signed source outcomes.'
    }
  } else {
    $layoutPath = [string](Require-Property $Capture 'layoutPath')
    $displayPath = [string](Require-Property $Capture 'displayPath')
    if ([IO.Path]::GetFullPath($displayPath) -ine
      [IO.Path]::GetFullPath((Join-Path $captureRoot "$expectedStem-display.txt"))) {
      Fail 'task 14 capture display path is not runner-owned.'
    }
    foreach ($pair in @(
        @($layoutPath, 'layoutSha256'),
        @($displayPath, 'displaySha256')
      )) {
      Require-AbsoluteFile ([string]$pair[0]) 'task 14 capture source file'
      if (-not (Test-PathInside ([string]$pair[0]) $ManifestDirectory) -or
        [string](Require-Property $Capture ([string]$pair[1])) -cne
          (Get-FileHash -LiteralPath ([string]$pair[0]) -Algorithm SHA256).Hash.ToLowerInvariant()) {
        Fail 'task 14 capture layout/display file is unbound.'
      }
    }
    if ([IO.Path]::GetFullPath($layoutPath) -ine [IO.Path]::GetFullPath($layoutDestination) -or
      [IO.File]::ReadAllText($displayPath) -cne [string]$sources[5].stdout) {
      Fail 'task 14 capture layout/display files do not match signed source commands.'
    }
  }
}

function Get-TextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes((Normalize-Text $Text))
  return ([BitConverter]::ToString(
      [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    )).Replace('-', '').ToLowerInvariant()
}

function Get-ArkTsMethodBlock([string]$Source, [string]$MethodName, [bool]$Required) {
  $escapedName = [regex]::Escape($MethodName)
  $matches = @([regex]::Matches(
      $Source,
      "(?m)^[\t ]*(?:(?:private|public|protected)[\t ]+)?(?:async[\t ]+)?$escapedName[\t ]*\("
    ))
  if ($matches.Count -eq 0) {
    if ($Required) { Fail "protected ArkTS method '$MethodName' is missing." }
    return $null
  }
  if ($matches.Count -ne 1) {
    Fail "protected ArkTS method '$MethodName' is not unique."
  }

  $state = 'code'
  $escaped = $false
  $blockStart = -1
  for ($index = $matches[0].Index; $index -lt $Source.Length; $index++) {
    $character = $Source[$index]
    $next = if ($index + 1 -lt $Source.Length) { $Source[$index + 1] } else { [char]0 }
    if ($state -eq 'line-comment') {
      if ($character -eq "`n") { $state = 'code' }
      continue
    }
    if ($state -eq 'block-comment') {
      if ($character -eq '*' -and $next -eq '/') { $state = 'code'; $index++ }
      continue
    }
    if ($state -in @('single', 'double', 'template')) {
      if ($escaped) { $escaped = $false; continue }
      if ($character -eq '\') { $escaped = $true; continue }
      if (($state -eq 'single' -and $character -eq "'") -or
        ($state -eq 'double' -and $character -eq '"') -or
        ($state -eq 'template' -and $character -eq '`')) {
        $state = 'code'
      }
      continue
    }
    if ($character -eq '/' -and $next -eq '/') { $state = 'line-comment'; $index++; continue }
    if ($character -eq '/' -and $next -eq '*') { $state = 'block-comment'; $index++; continue }
    if ($character -eq "'") { $state = 'single'; continue }
    if ($character -eq '"') { $state = 'double'; continue }
    if ($character -eq '`') { $state = 'template'; continue }
    if ($character -eq '{') { $blockStart = $index; break }
    if ($character -eq ';') { Fail "protected ArkTS method '$MethodName' has no body." }
  }
  if ($blockStart -lt 0) { Fail "protected ArkTS method '$MethodName' has no body." }

  $state = 'code'
  $escaped = $false
  $depth = 0
  for ($index = $blockStart; $index -lt $Source.Length; $index++) {
    $character = $Source[$index]
    $next = if ($index + 1 -lt $Source.Length) { $Source[$index + 1] } else { [char]0 }
    if ($state -eq 'line-comment') {
      if ($character -eq "`n") { $state = 'code' }
      continue
    }
    if ($state -eq 'block-comment') {
      if ($character -eq '*' -and $next -eq '/') { $state = 'code'; $index++ }
      continue
    }
    if ($state -in @('single', 'double', 'template')) {
      if ($escaped) { $escaped = $false; continue }
      if ($character -eq '\') { $escaped = $true; continue }
      if (($state -eq 'single' -and $character -eq "'") -or
        ($state -eq 'double' -and $character -eq '"') -or
        ($state -eq 'template' -and $character -eq '`')) {
        $state = 'code'
      }
      continue
    }
    if ($character -eq '/' -and $next -eq '/') { $state = 'line-comment'; $index++; continue }
    if ($character -eq '/' -and $next -eq '*') { $state = 'block-comment'; $index++; continue }
    if ($character -eq "'") { $state = 'single'; continue }
    if ($character -eq '"') { $state = 'double'; continue }
    if ($character -eq '`') { $state = 'template'; continue }
    if ($character -eq '{') { $depth++; continue }
    if ($character -eq '}') {
      $depth--
      if ($depth -eq 0) {
        return $Source.Substring($matches[0].Index, $index - $matches[0].Index + 1)
      }
    }
  }
  Fail "protected ArkTS method '$MethodName' has an unclosed body."
}

function Get-BytesSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Read-DerValue([byte[]]$Data, [ref]$Offset, [byte]$ExpectedTag) {
  if ($Offset.Value -ge $Data.Length -or $Data[$Offset.Value] -ne $ExpectedTag) {
    Fail "reviewer public key DER tag 0x$($ExpectedTag.ToString('x2')) is invalid."
  }
  $Offset.Value++
  if ($Offset.Value -ge $Data.Length) { Fail 'reviewer public key DER length is missing.' }
  $length = [int]$Data[$Offset.Value]
  $Offset.Value++
  if (($length -band 0x80) -ne 0) {
    $count = $length -band 0x7f
    if ($count -lt 1 -or $count -gt 4 -or $Offset.Value + $count -gt $Data.Length) {
      Fail 'reviewer public key DER length is invalid.'
    }
    $length = 0
    for ($index = 0; $index -lt $count; $index++) {
      $length = ($length -shl 8) -bor [int]$Data[$Offset.Value]
      $Offset.Value++
    }
  }
  if ($length -lt 0 -or $Offset.Value + $length -gt $Data.Length) {
    Fail 'reviewer public key DER value is truncated.'
  }
  $value = [byte[]]::new($length)
  [Array]::Copy($Data, $Offset.Value, $value, 0, $length)
  $Offset.Value += $length
  return $value
}

function Import-ReviewerRsa([string]$Path, [string]$ExpectedFingerprint = '') {
  Require-AbsoluteFile $Path 'runtime evidence reviewer public key'
  $pem = ([IO.File]::ReadAllText($Path) -replace '-----[^-]+-----', '' -replace '\s', '')
  try { $spki = [Convert]::FromBase64String($pem) } catch { Fail 'reviewer public key PEM is invalid.' }
  $fingerprint = Get-BytesSha256 $spki
  if ($ExpectedFingerprint -ne '' -and $fingerprint -cne $ExpectedFingerprint) {
    Fail 'runtime evidence reviewer public key fingerprint is not pinned.'
  }
  $offset = 0
  $outer = Read-DerValue $spki ([ref]$offset) 0x30
  if ($offset -ne $spki.Length) { Fail 'reviewer public key SPKI has trailing data.' }
  $outerOffset = 0
  [void](Read-DerValue $outer ([ref]$outerOffset) 0x30)
  $bitString = Read-DerValue $outer ([ref]$outerOffset) 0x03
  if ($outerOffset -ne $outer.Length -or $bitString.Length -lt 2 -or $bitString[0] -ne 0) {
    Fail 'reviewer public key SPKI bit string is invalid.'
  }
  $rsaBytes = $bitString[1..($bitString.Length - 1)]
  $rsaOffset = 0
  $rsaSequence = Read-DerValue $rsaBytes ([ref]$rsaOffset) 0x30
  $parameterOffset = 0
  $modulus = Read-DerValue $rsaSequence ([ref]$parameterOffset) 0x02
  $exponent = Read-DerValue $rsaSequence ([ref]$parameterOffset) 0x02
  if ($modulus[0] -eq 0) { $modulus = $modulus[1..($modulus.Length - 1)] }
  if ($modulus.Length -lt 384 -or $parameterOffset -ne $rsaSequence.Length) {
    Fail 'reviewer RSA key must be at least 3072 bits.'
  }
  $rsa = [Security.Cryptography.RSACng]::new()
  $rsa.ImportParameters([Security.Cryptography.RSAParameters]@{
      Modulus = [byte[]]$modulus
      Exponent = [byte[]]$exponent
    })
  return [pscustomobject]@{ Rsa = $rsa; Fingerprint = $fingerprint }
}

function Get-CanonicalRunRoot([object]$RunReceipt) {
  $root = [ordered]@{
    schemaVersion = 1
    domain = 'com.yuhaofeng.mih/runtime-ui-run-root/v1'
    trustDomain = [string](Require-Property $RunReceipt 'trustDomain')
    runId = [string](Require-Property $RunReceipt 'runId')
    runnerSha256 = [string](Require-Property $RunReceipt.captureRunner 'sha256')
    hdcPath = [string](Require-Property $RunReceipt.hdc 'path')
    hdcSha256 = [string](Require-Property $RunReceipt.hdc 'sha256')
    startedUtc = [string](Require-Property $RunReceipt 'startedUtc')
    endedUtc = [string](Require-Property $RunReceipt 'endedUtc')
    hapSha256 = [string](Require-Property $RunReceipt 'hapSha256')
    buildReceiptSha256 = [string](Require-Property $RunReceipt 'buildReceiptSha256')
    candidateDiffSha256 = [string](Require-Property $RunReceipt 'candidateDiffSha256')
    candidateIdentitySha256 = [string](Require-Property $RunReceipt 'candidateIdentitySha256')
    gitHead = [string](Require-Property $RunReceipt 'gitHead')
    routeName = [string](Require-Property $RunReceipt 'routeName')
    fontScale = [string](Require-Property $RunReceipt 'fontScale')
    density = [string](Require-Property $RunReceipt 'density')
    displayDumpSha256 = [string](Require-Property $RunReceipt 'displayDumpSha256')
    foregroundAaSha256 = [string](Require-Property $RunReceipt 'foregroundAaSha256')
    device = Require-Property $RunReceipt 'device'
    steps = @(Require-Property $RunReceipt 'steps')
    transcriptSha256 = [string](Require-Property $RunReceipt 'transcriptSha256')
    transcriptLength = [int64](Require-Property $RunReceipt 'transcriptLength')
    eventCount = [int](Require-Property $RunReceipt 'eventCount')
    finalLineSha256 = [string](Require-Property $RunReceipt 'finalLineSha256')
    stateReceiptSha256 = @(Require-Property $RunReceipt 'stateReceiptSha256')
    stateChainRootSha256 = [string](Require-Property $RunReceipt 'stateChainRootSha256')
  }
  return ($root | ConvertTo-Json -Compress -Depth 30)
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

function Get-UniqueRawAttribute([string]$Attributes, [string]$Name) {
  $matches = @([regex]::Matches(
      $Attributes,
      '"' + [regex]::Escape($Name) + '"\s*:\s*"(?<value>[^"]*)"'
    ))
  if ($matches.Count -ne 1) {
    Fail "task 14 system permission target lacks unique '$Name'."
  }
  return $matches[0].Groups['value'].Value
}

function Get-SystemCameraPermissionTarget([string]$LayoutPath) {
  $layoutText = [Text.Encoding]::GetEncoding(28591).GetString(
    [IO.File]::ReadAllBytes($LayoutPath)
  )
  $systemBundle = 'com.huawei.hmos.security.privacycenter'
  $systemPage = 'pages/permissionGrantDialog/PermissionGrantDialog'
  $controlId = 'permission_dialog_allow_button'
  if ([regex]::Matches($layoutText, [regex]::Escape($systemBundle)).Count -ne 1 -or
    [regex]::Matches($layoutText, [regex]::Escape($systemPage)).Count -ne 1) {
    Fail 'task 14 camera permission capture lacks the reviewed system bundle/page.'
  }
  $attributeObjects = @([regex]::Matches(
      $layoutText,
      '(?s)"attributes"\s*:\s*\{(?<attrs>[^{}]*?"id"\s*:\s*"' +
        [regex]::Escape($controlId) + '"[^{}]*?)\}\s*,\s*"children"'
    ))
  if ($attributeObjects.Count -ne 1) {
    Fail 'task 14 camera permission capture must contain one structural Allow button.'
  }
  $attributes = $attributeObjects[0].Groups['attrs'].Value
  $boundsText = Get-UniqueRawAttribute $attributes 'bounds'
  if ((Get-UniqueRawAttribute $attributes 'key') -cne $controlId -or
    (Get-UniqueRawAttribute $attributes 'type') -cne 'Button' -or
    (Get-UniqueRawAttribute $attributes 'clickable') -cne 'true' -or
    (Get-UniqueRawAttribute $attributes 'enabled') -cne 'true' -or
    (Get-UniqueRawAttribute $attributes 'visible') -cne 'true') {
    Fail 'task 14 camera permission target is not the reviewed visible clickable system button.'
  }
  return [pscustomobject]@{
    Bounds = Parse-Bounds $boundsText
    BoundsText = $boundsText
    SystemBundle = $systemBundle
    SystemPage = $systemPage
    ControlId = $controlId
  }
}

function Test-SystemPermissionForeground([string]$AaText) {
  $records = @([regex]::Matches(
      $AaText,
      '(?ms)^[ \t]*uri \[/com\.huawei\.hmos\.security\.privacycenter/' +
        'permissionmanager/PermissionGrantAbility\d+\]\s*\r?\n' +
        '(?<body>.*?)(?=^[ \t]*uri \[|^[ \t]*PendingWantRecords:|\z)'
    ))
  $foregroundRecords = @($records | Where-Object {
      $body = $_.Groups['body'].Value
      $body -match '(?m)^[ \t]*AbilityRecord ID #[^\r\n]*state #FOREGROUND[^\r\n]*\r?$' -and
      $body -match '(?m)^[ \t]*main name \[PermissionGrantAbility\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*bundle name \[com\.huawei\.hmos\.security\.privacycenter\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*ability type \[UIEXTENSION\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*app state #FOREGROUND[ \t]*\r?$'
    })
  return $foregroundRecords.Count -eq 1
}

function Test-SystemPhotoSaveForeground([string]$AaText) {
  $records = @([regex]::Matches(
      $AaText,
      '(?ms)^[ \t]*uri \[/com\.huawei\.hmos\.photos/phone_photos/' +
        'SaveUIExtensionAbility\d+\]\s*\r?\n' +
        '(?<body>.*?)(?=^[ \t]*uri \[|^[ \t]*PendingWantRecords:|\z)'
    ))
  $foregroundRecords = @($records | Where-Object {
      $body = $_.Groups['body'].Value
      $body -match '(?m)^[ \t]*AbilityRecord ID #[^\r\n]*state #FOREGROUND[^\r\n]*\r?$' -and
      $body -match '(?m)^[ \t]*main name \[SaveUIExtensionAbility\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*bundle name \[com\.huawei\.hmos\.photos\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*ability type \[UIEXTENSION\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*app state #FOREGROUND[ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*root host bundle name \[com\.yuhaofeng\.mih\][ \t]*\r?$' -and
      $body -match '(?m)^[ \t]*root host ability name \[EntryAbility\][ \t]*\r?$'
    })
  return $foregroundRecords.Count -eq 1
}

function Get-SystemPhotoSaveTarget([string]$LayoutPath) {
  $layoutText = [Text.Encoding]::GetEncoding(28591).GetString(
    [IO.File]::ReadAllBytes($LayoutPath)
  )
  $controlId = 'advanced_dialog_button_1'
  if ([regex]::Matches($layoutText, '"type"\s*:\s*"ModalPage"').Count -ne 1 -or
    [regex]::Matches($layoutText, '"type"\s*:\s*"UIExtensionComponent"').Count -ne 1) {
    Fail 'task 14 photo-save capture lacks the reviewed modal UI-extension structure.'
  }
  $attributeObjects = @([regex]::Matches(
      $layoutText,
      '(?s)"attributes"\s*:\s*\{(?<attrs>[^{}]*?"id"\s*:\s*"' +
        [regex]::Escape($controlId) + '"[^{}]*?)\}\s*,\s*"children"'
    ))
  if ($attributeObjects.Count -ne 1) {
    Fail 'task 14 photo-save capture must contain one structural Allow button.'
  }
  $attributes = $attributeObjects[0].Groups['attrs'].Value
  $boundsText = Get-UniqueRawAttribute $attributes 'bounds'
  if ((Get-UniqueRawAttribute $attributes 'key') -cne $controlId -or
    (Get-UniqueRawAttribute $attributes 'type') -cne 'Button' -or
    (Get-UniqueRawAttribute $attributes 'clickable') -cne 'true' -or
    (Get-UniqueRawAttribute $attributes 'enabled') -cne 'true' -or
    (Get-UniqueRawAttribute $attributes 'visible') -cne 'true') {
    Fail 'task 14 photo-save target is not the reviewed visible clickable system button.'
  }
  $bounds = Parse-Bounds $boundsText
  if ($null -eq $bounds -or $bounds.Width -le 0 -or $bounds.Height -le 0) {
    Fail 'task 14 photo-save target bounds are invalid.'
  }
  return [pscustomobject]@{
    Bounds = $bounds
    BoundsText = $boundsText
    SystemBundle = 'com.huawei.hmos.photos'
    SystemAbility = 'SaveUIExtensionAbility'
    ControlId = $controlId
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

function Matches-NodeSelector([object]$Node, [string]$Selector) {
  $separator = $Selector.IndexOf(':', [StringComparison]::Ordinal)
  if ($separator -le 0 -or $separator -eq $Selector.Length - 1) { return $false }
  $kind = $Selector.Substring(0, $separator)
  $value = $Selector.Substring($separator + 1)
  switch ($kind) {
    'id' { return (Attr $Node 'id') -ceq $value }
    'key' { return (Attr $Node 'key') -ceq $value }
    'text' { return (Node-Label $Node) -ceq $value }
    'type' { return (Attr $Node 'type') -ceq $value }
    'bounds' { return (Attr $Node 'bounds') -ceq $value }
    default { return $false }
  }
}

function Find-NodesWithAncestors([object]$Node, [string]$Selector, [object[]]$Ancestors = @()) {
  $matches = [Collections.Generic.List[object]]::new()
  if ($null -eq $Node) { return $matches }
  if (Matches-NodeSelector $Node $Selector) {
    $matches.Add([pscustomobject]@{ Node = $Node; Ancestors = $Ancestors })
  }
  foreach ($child in @($Node.children)) {
    foreach ($match in @(Find-NodesWithAncestors $child $Selector (@($Ancestors) + @($Node)))) {
      $matches.Add($match)
    }
  }
  return $matches
}

function Find-ToolbarPairs([object]$Node, [object[]]$Ancestors = @()) {
  $pairs = [Collections.Generic.List[object]]::new()
  $children = @($Node.children)
  for ($index = 1; $index -lt $children.Count; $index++) {
    if ((Attr $children[$index] 'type') -ceq 'SaveButton' -and
      (Attr $children[$index - 1] 'type') -ceq 'Row' -and
      (Attr $children[$index - 1] 'clickable') -ceq 'true') {
      $pairs.Add([pscustomobject]@{
          Save = $children[$index]
          Camera = $children[$index - 1]
          Ancestors = @($Ancestors) + @($Node)
        })
    }
  }
  foreach ($child in $children) {
    foreach ($pair in @(Find-ToolbarPairs $child (@($Ancestors) + @($Node)))) { $pairs.Add($pair) }
  }
  return $pairs
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
$manifestDirectory = Split-Path -Parent $ManifestPath
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
if ($LASTEXITCODE -ne 0) {
  Fail 'repositoryRoot must belong to a Git worktree.'
}
$gitPathPrefix = Normalize-Text (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      rev-parse --show-prefix 2>$null) -join "`n"
)
if ($LASTEXITCODE -ne 0) {
  Fail 'repositoryRoot must expose its Git worktree-relative prefix.'
}
$expectedProjectRoot = if ([string]::IsNullOrEmpty($gitPathPrefix)) {
  [IO.Path]::GetFullPath($resolvedGitRoot).TrimEnd('\', '/')
} else {
  [IO.Path]::GetFullPath((Join-Path $resolvedGitRoot $gitPathPrefix)).TrimEnd('\', '/')
}
if ($expectedProjectRoot -cne $repositoryRoot) {
  Fail 'repositoryRoot must be the exact project root inside its Git worktree.'
}
$candidateDiffPath = [string](Require-Property $manifest 'candidateDiffPath')
Require-AbsoluteFile $candidateDiffPath 'candidateDiffPath'
if ($task -eq 14 -and -not (Test-PathInside $candidateDiffPath $manifestDirectory)) {
  Fail 'task 14 candidateDiffPath must be an immutable artifact inside the evidence directory.'
}
if ((Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
  $candidateHash.ToLowerInvariant()) {
  Fail 'candidateDiffSha256 does not match candidateDiffPath.'
}
$declaredSourceKind = [string](Require-Property $manifest 'source')
$commitSha = [string](Require-Property $manifest 'commitSha')
if ($commitSha -ne '' -and $commitSha -notmatch '^[0-9a-f]{40}$') { Fail 'commitSha must be empty or 40 hex characters.' }
if ($task -eq 14 -and $declaredSourceKind -eq 'production' -and $commitSha -eq '') {
  Fail 'task 14 production evidence must bind a non-empty amended commit SHA.'
}
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
if ($task -eq 14 -and -not (Test-PathInside $hapPath $manifestDirectory)) {
  Fail 'task 14 hapPath must be an immutable HAP inside the evidence directory.'
}
if ($task -ne 14 -and [IO.Path]::GetFullPath($hapPath) -ine [IO.Path]::GetFullPath($canonicalHapPath)) {
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
if ($task -eq 14 -and -not (Test-PathInside $buildReceiptPath $manifestDirectory)) {
  Fail 'task 14 buildReceiptPath must be an immutable receipt inside the evidence directory.'
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
$sourceKind = $declaredSourceKind
if ($sourceKind -notin @('production', 'harness')) { Fail 'source must be production or harness.' }
$harnessPagePath = Join-Path $repositoryRoot 'entry\src\main\ets\pages\RuntimeHarnessPage.ets'
$entryAbilityPath = Join-Path $repositoryRoot 'entry\src\main\ets\entryability\EntryAbility.ets'
$mainPagesPath = Join-Path $repositoryRoot 'entry\src\main\resources\base\profile\main_pages.json'
$producerTemplateRoot = Join-Path $PSScriptRoot 'runtime-evidence-templates'
$hasHarnessPage = Test-Path -LiteralPath $harnessPagePath -PathType Leaf
$diffPathPrefix = if ([string]::IsNullOrEmpty($gitPathPrefix)) {
  ''
} else {
  [regex]::Escape($gitPathPrefix.Replace('\', '/'))
}
$derivedSource = if ($hasHarnessPage -and $candidateKind -eq 'workingTree' -and
  $gitDiff -match "(?m)^\+\+\+ b/${diffPathPrefix}entry/src/main/ets/pages/RuntimeHarnessPage\.ets$") {
  'harness'
} else {
  'production'
}
if ($sourceKind -cne $derivedSource) {
  Fail 'source must be derived from the bound production or isolated harness candidate.'
}
if ($task -eq 14 -and $sourceKind -eq 'harness') {
  $harnessDisclosure = Require-Property $manifest 'harnessDisclosure'
  if ([string](Require-Property $harnessDisclosure 'kind') -cne 'auditableRouteStateHarness' -or
    [string](Require-Property $harnessDisclosure 'productionSuccessClaim') -cne 'none') {
    Fail 'task 14 harness evidence must disclose auditable route/state scope and no production success claim.'
  }
  $harnessDisclosurePath = [string](Require-Property $harnessDisclosure 'path')
  Require-AbsoluteFile $harnessDisclosurePath 'task 14 harness disclosure'
  if (-not (Test-PathInside $harnessDisclosurePath $manifestDirectory)) {
    Fail 'task 14 harness disclosure must be stored inside the immutable evidence directory.'
  }
}
$derivedFontScale = 1.0
if ($derivedSource -eq 'harness') {
  Require-AbsoluteFile $entryAbilityPath 'harness EntryAbility'
  Require-AbsoluteFile $mainPagesPath 'harness main_pages'
  $templateFiles = @(
    'RuntimeHarnessPage.ets',
    'main_pages.json',
    $(if ($fontScale -eq 3.2) { 'EntryAbility.font32.ets' } else { 'EntryAbility.default.ets' })
  )
  foreach ($templateFile in $templateFiles) {
    Require-AbsoluteFile (Join-Path $producerTemplateRoot $templateFile) "trusted $templateFile template"
  }
  $harnessPage = Normalize-Text ([IO.File]::ReadAllText($harnessPagePath))
  $entryAbility = Normalize-Text ([IO.File]::ReadAllText($entryAbilityPath))
  $mainPages = Normalize-Text ([IO.File]::ReadAllText($mainPagesPath))
  $entryTemplateName = if ($fontScale -eq 3.2) { 'EntryAbility.font32.ets' } else { 'EntryAbility.default.ets' }
  if ($harnessPage -cne (Normalize-Text ([IO.File]::ReadAllText(
        (Join-Path $producerTemplateRoot 'RuntimeHarnessPage.ets')))) -or
    $entryAbility -cne (Normalize-Text ([IO.File]::ReadAllText(
        (Join-Path $producerTemplateRoot $entryTemplateName)))) -or
    $mainPages -cne (Normalize-Text ([IO.File]::ReadAllText(
        (Join-Path $producerTemplateRoot 'main_pages.json')))) -or
    $gitDiff -notmatch "(?m)^\+\+\+ b/${diffPathPrefix}entry/src/main/ets/entryability/EntryAbility\.ets$") {
    Fail 'harness EntryAbility, RuntimeHarnessPage, and main_pages must exactly match trusted templates.'
  }
  if ($fontScale -eq 3.2) { $derivedFontScale = 3.2 }
}
if (($fontScale -ne $derivedFontScale) -or
  ((($fontScale -eq 3.2) -or $routeName -eq '/custommodel/CustomModelMainActivity') -and
    $derivedSource -ne 'harness')) {
  Fail 'fontScale/hidden-route claims do not match the bound production or harness source.'
}
if ($task -eq 14 -and $sourceKind -eq 'production' -and $fontScale -ne 1.0) {
  Fail 'task 14 production evidence must use the real 1.0 font-scale capture.'
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
  $evidenceStatus = if ($state.PSObject.Properties.Name -contains 'evidenceStatus') {
    [string]$state.evidenceStatus
  } else {
    'captured'
  }
  if ($evidenceStatus -notin @('captured', 'parked')) {
    Fail "state '$name' has an invalid evidenceStatus."
  }
  if ($evidenceStatus -eq 'parked') {
    $parkingReason = [string](Require-Property $state 'parkingReason')
    if ([string]::IsNullOrWhiteSpace($parkingReason) -or
      $state.PSObject.Properties.Name -contains 'layout' -or $state.PSObject.Properties.Name -contains 'screenshot') {
      Fail "parked state '$name' must document its reason without claiming a captured layout or screenshot."
    }
    $stateData[$name] = [pscustomobject]@{
      PreserveFrom = ''
      Selectors = @()
      Hashes = @{}
      VisualRegions = @{}
      EvidenceStatus = $evidenceStatus
      CaptureSource = ''
    }
    continue
  }
  $captureSource = if ($state.PSObject.Properties.Name -contains 'captureSource') {
    [string]$state.captureSource
  } else {
    ''
  }
  if ($task -eq 14 -and $captureSource -ne $sourceKind) {
    Fail "task 14 state '$name' captureSource must match the manifest source."
  }
  $layoutPath = [string](Require-Property $state 'layout')
  $screenshotPath = [string](Require-Property $state 'screenshot')
  Require-AbsoluteFile $layoutPath "state '$name' layout"
  Require-AbsoluteFile $screenshotPath "state '$name' screenshot"
  if ([IO.Path]::GetExtension($screenshotPath).ToLowerInvariant() -notin @('.jpg', '.jpeg')) {
    Fail "state '$name' screenshot must be JPEG."
  }
  $screenshotBytes = [IO.File]::ReadAllBytes($screenshotPath)
  if ($screenshotBytes.Length -lt 128 -or $screenshotBytes[0] -ne 0xFF -or $screenshotBytes[1] -ne 0xD8 -or
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
  $requiredClickableSelectors = if ($state.PSObject.Properties.Name -contains 'requiredClickableSelectors') {
    @($state.requiredClickableSelectors)
  } else { @() }
  if ($requiredTexts.Count -eq 0 -or
    ($requiredClickableTexts.Count -eq 0 -and $requiredClickableSelectors.Count -eq 0)) {
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
  $scrollReachableEntries = if ($state.PSObject.Properties.Name -contains 'scrollReachableTexts') {
    @($state.scrollReachableTexts)
  } else { @() }
  $scrollReachableNodes = [Collections.Generic.List[object]]::new()
  foreach ($entry in $scrollReachableEntries) {
    $selector = [string](Require-Property $entry 'selector')
    $scrollSelector = [string](Require-Property $entry 'scrollSelector')
    if ($selector -notmatch '^text:.+' -or $scrollSelector -notin @('type:Scroll', 'type:List')) {
      Fail "state '$name' scroll-reachable evidence must name one text selector and its Scroll or List ancestor."
    }
    $matches = @(Find-NodesWithAncestors $routeRoot[0] $selector)
    if ($matches.Count -ne 1) { Fail "state '$name' scroll-reachable selector '$selector' must identify one node." }
    $scrollAncestors = @($matches[0].Ancestors | Where-Object {
        Matches-NodeSelector $_ $scrollSelector
      })
    if ($scrollAncestors.Count -ne 1 -or (Attr $scrollAncestors[0] 'scrollable') -ne 'true') {
      Fail "state '$name' scroll-reachable selector '$selector' must have one scrollable ancestor."
    }
    $reachableBounds = Parse-Bounds (Attr $matches[0].Node 'bounds')
    $reachableOriginalBounds = Parse-Bounds (Attr $matches[0].Node 'origBounds')
    $scrollBounds = Parse-Bounds (Attr $scrollAncestors[0] 'bounds')
    $horizontalReachability = $scrollSelector -eq 'type:List'
    if ($null -eq $reachableBounds -or $null -eq $reachableOriginalBounds -or $null -eq $scrollBounds -or
      ($horizontalReachability -and $reachableOriginalBounds.Right -le $scrollBounds.Right) -or
      (-not $horizontalReachability -and $reachableOriginalBounds.Bottom -le $scrollBounds.Bottom)) {
      Fail "state '$name' scroll-reachable selector '$selector' must prove text extends beyond its scroll viewport."
    }
    $afterLayoutPath = [string](Require-Property $entry 'afterScrollLayout')
    $afterScreenshotPath = [string](Require-Property $entry 'afterScrollScreenshot')
    Require-AbsoluteFile $afterLayoutPath "state '$name' after-scroll layout"
    Require-AbsoluteFile $afterScreenshotPath "state '$name' after-scroll screenshot"
    if ([IO.Path]::GetExtension($afterScreenshotPath).ToLowerInvariant() -notin @('.jpg', '.jpeg')) {
      Fail "state '$name' after-scroll screenshot must be JPEG."
    }
    try {
      $afterLayout = Get-Content -LiteralPath $afterLayoutPath -Raw -Encoding utf8 | ConvertFrom-Json
      $afterScreenshot = [Drawing.Image]::FromFile($afterScreenshotPath)
      $afterScreenshotWidth = $afterScreenshot.Width
      $afterScreenshotHeight = $afterScreenshot.Height
      $afterScreenshot.Dispose()
    } catch {
      Fail "state '$name' after-scroll layout/screenshot must be readable."
    }
    if ($afterScreenshotWidth -ne $displayWidthPx -or $afterScreenshotHeight -ne $displayHeightPx) {
      Fail "state '$name' after-scroll screenshot dimensions do not match the captured display."
    }
    $afterRoute = @((Flatten-Nodes $afterLayout) | Where-Object { (Attr $_ 'key') -ceq $routeName })
    if ($afterRoute.Count -ne 1) { Fail "state '$name' after-scroll layout must bind the same runtime route." }
    $afterMatches = @(Find-NodesWithAncestors $afterRoute[0] $selector)
    if ($afterMatches.Count -ne 1) { Fail "state '$name' after-scroll selector '$selector' is not reachable." }
    $afterScrollAncestors = @($afterMatches[0].Ancestors | Where-Object {
        Matches-NodeSelector $_ $scrollSelector
      })
    $afterOriginalBounds = Parse-Bounds (Attr $afterMatches[0].Node 'origBounds')
    $afterScrollBounds = Parse-Bounds (Attr $afterScrollAncestors[0] 'bounds')
    if ($afterScrollAncestors.Count -ne 1 -or (Attr $afterScrollAncestors[0] 'scrollable') -ne 'true' -or
      $null -eq $afterOriginalBounds -or $null -eq $afterScrollBounds -or
      ($horizontalReachability -and ($afterOriginalBounds.Left -lt $afterScrollBounds.Left -or
        $afterOriginalBounds.Right -gt $afterScrollBounds.Right)) -or
      (-not $horizontalReachability -and $afterOriginalBounds.Bottom -gt $afterScrollBounds.Bottom)) {
      Fail "state '$name' after-scroll evidence must retain the same text within its scrollable ancestor."
    }
    $beforePixels = Get-VisualRegionData $screenshotPath $scrollBounds $name $selector
    $afterPixels = Get-VisualRegionData $afterScreenshotPath $afterScrollBounds $name $selector
    if ($beforePixels.LumaStandardDeviation -lt 2.0 -or $afterPixels.LumaStandardDeviation -lt 2.0 -or
      (Get-VisualRegionMeanAbsoluteError $beforePixels $afterPixels) -le 2.0) {
      Fail "state '$name' after-scroll evidence must visibly differ from the top-of-scroll capture."
    }
    $scrollReachableNodes.Add($matches[0].Node)
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
    if (-not [string]::IsNullOrWhiteSpace($label) -and -not $scrollReachableNodes.Contains($node)) {
      $originalBoundsText = Attr $node 'origBounds'
      $originalBounds = Parse-Bounds $originalBoundsText
      if ($null -eq $originalBounds -or
        $originalBounds.Left -ne $bounds.Left -or $originalBounds.Top -ne $bounds.Top -or
        $originalBounds.Right -ne $bounds.Right -or $originalBounds.Bottom -ne $bounds.Bottom) {
        Fail "state '$name' contains a visibly clipped label."
      }
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
  foreach ($selector in $requiredClickableSelectors) {
    $control = Get-PreservationNode $nodes ([string]$selector) $name
    if (-not (Is-Visible $control) -or (Attr $control 'clickable') -ne 'true' -or
      (Attr $control 'enabled') -eq 'false') {
      Fail "state '$name' required control '$selector' must be visible, enabled, and clickable."
    }
    $bounds = Parse-Bounds (Attr $control 'bounds')
    if (($bounds.Width / $density) -lt $minPrimaryTargetVp -or ($bounds.Height / $density) -lt $minPrimaryTargetVp) {
      Fail "state '$name' primary control '$selector' is undersized."
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
    EvidenceStatus = $evidenceStatus
    CaptureSource = $captureSource
    LayoutPath = [IO.Path]::GetFullPath($layoutPath)
    ScreenshotPath = [IO.Path]::GetFullPath($screenshotPath)
    Labels = $labels
  }
}

if ($task -eq 14 -and $sourceKind -eq 'production') {
  $requiredTask14States = @(
    'front-no-subject', 'retry-no-subject', 'rear-person-success', 'rear-person-reentry'
  )
  foreach ($requiredState in $requiredTask14States) {
    if (-not $stateData.ContainsKey($requiredState)) {
      Fail "task 14 production evidence is missing required state '$requiredState'."
    }
  }
  foreach ($capturedState in $requiredTask14States) {
    if ($stateData[$capturedState].EvidenceStatus -ne 'captured' -or
      $stateData[$capturedState].CaptureSource -ne 'production') {
      Fail "task 14 state '$capturedState' must be a real production capture."
    }
  }
}
if ($task -eq 14 -and $sourceKind -eq 'harness') {
  if ($routeName -cne '/hms/PortraitSegmentationActivity') {
    Fail 'task 14 harness evidence must exercise only the hidden portrait route.'
  }
  $contracts = @(
    [pscustomobject]@{ Name = 'initial'; Pred = ''; Action = 'open-route'; Controls = @('harness-portrait-route', 'system-camera-permission-allow'); Events = @(); Intermediate = $false },
    [pscustomobject]@{ Name = 'preset-selected'; Pred = 'initial'; Action = 'select-preset'; Controls = @('portrait-preset-2'); Events = @(); Intermediate = $false },
    [pscustomobject]@{ Name = 'custom-background-cancel'; Pred = 'preset-selected'; Action = 'cancel-background-picker'; Controls = @('portrait-background-strip-swipe', 'portrait-custom-background', 'key:Back'); Events = @(); Intermediate = $true },
    [pscustomobject]@{ Name = 'rear-camera'; Pred = 'custom-background-cancel'; Action = 'switch-camera'; Controls = @('portrait-switch-camera'); Events = @('camera.position.observed'); Intermediate = $false },
    [pscustomobject]@{ Name = 'reentry'; Pred = 'rear-camera'; Action = 'leave-and-reenter'; Controls = @('key:Back', 'harness-portrait-route'); Events = @('camera.restore'); Intermediate = $false },
    [pscustomobject]@{ Name = 'transient-failure'; Pred = 'reentry'; Action = 'audited-segmentation-failure'; Controls = @(); Events = @('service.failure'); Intermediate = $false },
    [pscustomobject]@{ Name = 'retry-success'; Pred = 'transient-failure'; Action = 'retry-segmentation'; Controls = @('portrait-retry'); Events = @('service.success'); Intermediate = $false },
    [pscustomobject]@{ Name = 'save-success'; Pred = 'retry-success'; Action = 'save-success'; Controls = @('portrait-save', 'system-photo-save-allow'); Events = @(); Intermediate = $false }
  )
  $runReceiptPath = [string](Require-Property $manifest 'runReceiptPath')
  Require-AbsoluteFile $runReceiptPath 'task 14 run receipt'
  if (-not (Test-PathInside $runReceiptPath $manifestDirectory) -or
    [string](Require-Property $manifest 'runReceiptSha256') -cne
      (Get-FileHash -LiteralPath $runReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
    Fail 'task 14 manifest must hash-bind one run receipt inside the evidence directory.'
  }
  try {
    $runReceipt = Get-Content -LiteralPath $runReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    Fail 'task 14 run receipt must be valid UTF-8 JSON.'
  }
  $runId = [string](Require-Property $runReceipt 'runId')
  $captureRunner = Require-Property $runReceipt 'captureRunner'
  $runnerPath = [string](Require-Property $captureRunner 'path')
  Require-AbsoluteFile $runnerPath 'task 14 capture runner'
  $trustedRunnerPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'capture-runtime-ui-run.ps1'))
  $trustedRunnerHash =
    (Get-FileHash -LiteralPath $trustedRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $buildReceiptHash =
    (Get-FileHash -LiteralPath $buildReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $displayDumpHash =
    (Get-FileHash -LiteralPath $displayDumpPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ([int](Require-Property $runReceipt 'schemaVersion') -ne 1 -or
    $runId -notmatch '^[0-9a-f]{32}$' -or
    [IO.Path]::GetFullPath($runnerPath) -ine $trustedRunnerPath -or
    [int](Require-Property $captureRunner 'version') -ne 1 -or
    [string](Require-Property $captureRunner 'sha256') -cne $trustedRunnerHash -or
    [string](Require-Property $runReceipt 'hapSha256') -cne $actualHapHash -or
    [string](Require-Property $runReceipt 'buildReceiptSha256') -cne $buildReceiptHash -or
    [string](Require-Property $runReceipt 'candidateDiffSha256') -cne $candidateHash -or
    [string](Require-Property $runReceipt 'candidateIdentitySha256') -cne $candidateIdentitySha256 -or
    [string](Require-Property $runReceipt 'gitHead') -cne $headSha -or
    [string](Require-Property $runReceipt 'routeName') -cne $routeName -or
    [double](Require-Property $runReceipt 'fontScale') -ne $fontScale -or
    [double](Require-Property $runReceipt 'density') -ne $density -or
    [string](Require-Property $runReceipt 'displayDumpSha256') -cne $displayDumpHash -or
    [string](Require-Property $runReceipt 'foregroundAaSha256') -cne
      (Get-FileHash -LiteralPath $aaDumpPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
    Fail 'task 14 run receipt does not bind runner/HAP/build/candidate/HEAD/route/display/AA.'
  }
  try {
    $runStarted = [datetime]::Parse([string](Require-Property $runReceipt 'startedUtc')).ToUniversalTime()
    $runEnded = [datetime]::Parse([string](Require-Property $runReceipt 'endedUtc')).ToUniversalTime()
  } catch {
    Fail 'task 14 run receipt UTC bounds are invalid.'
  }
  if ($runStarted -ge $runEnded) { Fail 'task 14 run receipt UTC bounds are not ordered.' }
  $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
  $rootPath = [string](Require-Property $manifest 'runRootPath')
  $signaturePath = [string](Require-Property $manifest 'runRootSignaturePath')
  Require-AbsoluteFile $rootPath 'task 14 canonical run root'
  Require-AbsoluteFile $signaturePath 'task 14 run-root signature'
  if (-not (Test-PathInside $rootPath $manifestDirectory) -or
    -not (Test-PathInside $signaturePath $manifestDirectory) -or
    [string](Require-Property $manifest 'runRootSha256') -cne
      (Get-FileHash -LiteralPath $rootPath -Algorithm SHA256).Hash.ToLowerInvariant() -or
    [string](Require-Property $manifest 'runRootSignatureSha256') -cne
      (Get-FileHash -LiteralPath $signaturePath -Algorithm SHA256).Hash.ToLowerInvariant()) {
    Fail 'task 14 manifest must hash-bind its canonical root and detached signature.'
  }
  $rootBytes = [IO.File]::ReadAllBytes($rootPath)
  $canonicalRoot = Get-CanonicalRunRoot $runReceipt
  if ($utf8Strict.GetString($rootBytes) -cne $canonicalRoot) {
    Fail 'task 14 signed run root is not exact canonical JSON.'
  }
  try {
    $signatureEnvelope = Get-Content -LiteralPath $signaturePath -Raw -Encoding utf8 |
      ConvertFrom-Json
    $signatureBytes = [Convert]::FromBase64String(
      [string](Require-Property $signatureEnvelope 'signatureBase64')
    )
  } catch {
    Fail 'task 14 detached run-root signature envelope is invalid.'
  }
  $productionKeyPath = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot 'runtime-evidence-reviewer-public.pem')
  )
  $productionFingerprint = '8cf68478e1fcb46745e3c7b8a18235caca42c3607eff84d96e8e74dd33f979e6'
  $reviewer = Import-ReviewerRsa $productionKeyPath $productionFingerprint
  try {
    if ([int](Require-Property $signatureEnvelope 'schemaVersion') -ne 1 -or
      [string](Require-Property $signatureEnvelope 'algorithm') -cne 'RSA-PSS-SHA256-MGF1-SHA256-SALT32' -or
      [string](Require-Property $signatureEnvelope 'rootSha256') -cne
        (Get-BytesSha256 $rootBytes) -or
      [string](Require-Property $signatureEnvelope 'keyFingerprint') -cne $reviewer.Fingerprint -or
      [string](Require-Property $runReceipt 'trustDomain') -cne 'production') {
      Fail 'task 14 signed run-root envelope has the wrong algorithm/key/domain/root.'
    }
    $prefix = $utf8Strict.GetBytes("runtime-ui-run-root-v1`0")
    $signedBytes = [byte[]]::new($prefix.Length + $rootBytes.Length)
    [Array]::Copy($prefix, 0, $signedBytes, 0, $prefix.Length)
    [Array]::Copy($rootBytes, 0, $signedBytes, $prefix.Length, $rootBytes.Length)
    if (-not $reviewer.Rsa.VerifyData(
        $signedBytes,
        $signatureBytes,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pss
      )) {
      Fail 'task 14 canonical run root has no trusted reviewer RSA-PSS signature.'
    }
  } finally {
    $reviewer.Rsa.Dispose()
  }
  $device = Require-Property $runReceipt 'device'
  foreach ($deviceField in @('transportId', 'serial', 'fingerprint', 'packageFingerprint')) {
    if ([string]::IsNullOrWhiteSpace([string](Require-Property $device $deviceField))) {
      Fail "task 14 run receipt device.$deviceField must be non-empty."
    }
  }
  $transcriptPath = [string](Require-Property $runReceipt 'transcriptPath')
  Require-AbsoluteFile $transcriptPath 'task 14 capture transcript'
  if (-not (Test-PathInside $transcriptPath $manifestDirectory) -or
    [string](Require-Property $runReceipt 'transcriptSha256') -cne
      (Get-FileHash -LiteralPath $transcriptPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
    Fail 'task 14 run receipt must hash-bind one capture transcript inside the evidence directory.'
  }
  $runnerHash = [string]$captureRunner.sha256
  $transcriptBytes = [IO.File]::ReadAllBytes($transcriptPath)
  $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
  try {
    $transcriptText = $utf8Strict.GetString($transcriptBytes)
    if (-not $transcriptText.EndsWith("`n")) { Fail 'task 14 capture transcript must end at a JSONL boundary.' }
    $rawTranscriptLines = @($transcriptText.TrimEnd("`r", "`n") -split "`r?`n")
    $transcriptLines = @($rawTranscriptLines |
        ForEach-Object { $_ | ConvertFrom-Json })
  } catch {
    Fail 'task 14 capture transcript must be append-only UTF-8 JSONL.'
  }
  $eventsById = @{}
  $nonces = @{}
  $previousLineHash = ('0' * 64)
  $setupByteEnd = 0
  for ($eventIndex = 0; $eventIndex -lt $transcriptLines.Count; $eventIndex++) {
    $event = $transcriptLines[$eventIndex]
    $eventId = [string](Require-Property $event 'eventId')
    $eventRunId = [string](Require-Property $event 'runId')
    $nonce = [string](Require-Property $event 'nonce')
    try { $eventUtc = [datetime]::Parse([string](Require-Property $event 'utc')).ToUniversalTime() } catch {
      Fail "task 14 transcript event '$eventId' has invalid UTC."
    }
    if ([string]::IsNullOrWhiteSpace($eventId) -or $eventsById.ContainsKey($eventId) -or
      [int](Require-Property $event 'sequence') -ne $eventIndex -or
      $eventRunId -cne $runId -or
      $nonce -notmatch "^$([regex]::Escape($runId)):$($eventIndex.ToString('D6')):[0-9a-f]{32}$" -or
      $nonces.ContainsKey($nonce) -or
      [string](Require-Property $event 'previousLineSha256') -cne $previousLineHash -or
      [string](Require-Property $event 'captureRunnerSha256') -cne $runnerHash -or
      $eventUtc -lt $runStarted -or $eventUtc -gt $runEnded) {
      Fail "task 14 transcript event '$eventId' is not bound to this run/runner/nonce/UTC."
    }
    $eventsById[$eventId] = $event
    $nonces[$nonce] = $true
    $lineBytes = $utf8Strict.GetBytes($rawTranscriptLines[$eventIndex] + "`n")
    $previousLineHash = Get-BytesSha256 $lineBytes
    if ($event.PSObject.Properties.Name -notcontains 'stateName') {
      $setupByteEnd += $lineBytes.Length
    }
  }
  if ([int](Require-Property $runReceipt 'eventCount') -ne $transcriptLines.Count -or
    [int64](Require-Property $runReceipt 'transcriptLength') -ne $transcriptBytes.Length -or
    [string](Require-Property $runReceipt 'finalLineSha256') -cne $previousLineHash) {
    Fail 'task 14 signed transcript count/length/final hash does not close.'
  }
  $hdc = Require-Property $runReceipt 'hdc'
  $hdcPath = [string](Require-Property $hdc 'path')
  Require-AbsoluteFile $hdcPath 'task 14 HDC executable'
  if ([string](Require-Property $hdc 'sha256') -cne
    (Get-FileHash -LiteralPath $hdcPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
    Fail 'task 14 signed HDC executable hash is invalid.'
  }
  foreach ($processEvent in @($transcriptLines | Where-Object {
        $_.PSObject.Properties.Name -contains 'argv'
      })) {
    try {
      $started = [datetime]::Parse([string](Require-Property $processEvent 'startedUtc')).ToUniversalTime()
      $ended = [datetime]::Parse([string](Require-Property $processEvent 'endedUtc')).ToUniversalTime()
    } catch {
      Fail "task 14 process event '$($processEvent.eventId)' has invalid UTC."
    }
    if ([IO.Path]::GetFullPath([string](Require-Property $processEvent 'executablePath')) -ine
      [IO.Path]::GetFullPath($hdcPath) -or
      [string](Require-Property $processEvent 'stdoutSha256') -cne
        (Get-BytesSha256 $utf8Strict.GetBytes([string](Require-Property $processEvent 'stdout'))) -or
      [string](Require-Property $processEvent 'stderrSha256') -cne
        (Get-BytesSha256 $utf8Strict.GetBytes([string](Require-Property $processEvent 'stderr'))) -or
      [bool](Require-Property $processEvent 'timedOut') -or
      [int](Require-Property $processEvent 'timeoutMilliseconds') -le 0 -or
      ([int](Require-Property $processEvent 'exitCode') -ne 0 -and
        [string]$processEvent.type -notin @(
          'source.picker.layout-attempt', 'source.picker.recv-layout-attempt'
        )) -or $started -gt $ended) {
      Fail "task 14 process event '$($processEvent.eventId)' lacks signed raw HDC outcome."
    }
    $processType = [string]$processEvent.type
    $processArgv = @($processEvent.argv)
    for ($argvIndex = 0; $argvIndex -le $processArgv.Count - 3; $argvIndex++) {
      if ([string]$processArgv[$argvIndex] -ceq 'shell' -and
        [string]$processArgv[$argvIndex + 1] -ceq 'bm' -and
        [string]$processArgv[$argvIndex + 2] -ceq 'grant') {
        Fail "task 14 process event '$($processEvent.eventId)' attempts an external permission grant."
      }
    }
    if (($processType -ceq 'run.device' -and
        ($processArgv -join "`0") -cne (@('list', 'targets', '-v') -join "`0")) -or
      ($processType -ceq 'source.hilog' -and
        ($processArgv -join "`0") -cne
          (@(
              '-t', [string]$device.transportId,
              'shell', 'hilog', '-x', '-T', 'MIH_RUNTIME_EVIDENCE'
            ) -join "`0")) -or
      ($processType -ceq 'source.capture.display' -and
        ($processArgv -join "`0") -cne
          (@(
              '-t', [string]$device.transportId,
              'shell', 'hidumper', '-s', 'DisplayManagerService', '-a', '-a'
            ) -join "`0")) -or
      ($processType -ceq 'source.permission.state-after' -and
        ($processArgv -join "`0") -cne
          (@(
              '-t', [string]$device.transportId,
              'shell', 'atm', 'dump', '-t', '-b', 'com.yuhaofeng.mih'
            ) -join "`0")) -or
      ($processType -ceq 'source.permission.wait-aa' -and
        ($processArgv -join "`0") -cne
          (@(
              '-t', [string]$device.transportId,
              'shell', 'aa', 'dump', '-a'
            ) -join "`0")) -or
      ($processType -ceq 'source.save-dialog.wait-aa' -and
        ($processArgv -join "`0") -cne
          (@(
              '-t', [string]$device.transportId,
              'shell', 'aa', 'dump', '-a'
            ) -join "`0"))) {
      Fail "task 14 process event '$($processEvent.eventId)' uses an unreviewed HDC argv."
    }
  }
  $expectedRunTypes = @(
    'run.install', 'run.clean-data', 'run.start', 'run.foreground-aa', 'run.permission-before'
  )
  $targetPrefix = @('-t', [string]$device.transportId)
  $captureSourceClaims = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $captureEvents = @($transcriptLines | Where-Object {
      [string]$_.type -in @('capture', 'picker.capture')
    })
  $expectedCaptureNames = @(
    'launcher', 'permission-dialog', 'initial', 'preset-selected',
    'custom-background-swiped', 'picker-intermediate', 'custom-background-cancel',
    'rear-camera', 'reentry-launcher', 'reentry', 'transient-failure',
    'retry-success', 'save-dialog', 'save-success'
  )
  $actualCaptureNames = @($captureEvents | ForEach-Object { [string]$_.captureName })
  $actualCaptureNameSet = (@($actualCaptureNames | Sort-Object) -join "`0")
  $expectedCaptureNameSet = (@($expectedCaptureNames | Sort-Object) -join "`0")
  if ($actualCaptureNameSet -cne $expectedCaptureNameSet) {
    Fail 'task 14 transcript has missing, duplicate, or unreviewed captures.'
  }
  foreach ($captureEvent in $captureEvents) {
    Assert-Task14CaptureEvent $captureEvent $eventsById $targetPrefix $manifestDirectory
    foreach ($sourceId in @($captureEvent.sourceCommandEventIds)) {
      if (-not $captureSourceClaims.Add([string]$sourceId)) {
        Fail "task 14 capture source command '$sourceId' is claimed more than once."
      }
    }
  }
  $captureSourceEvents = @($transcriptLines | Where-Object {
      [string]$_.type -match '^source\.(capture|picker)\.'
    })
  if ($captureSourceClaims.Count -ne $captureSourceEvents.Count -or
    @($captureSourceEvents | Where-Object {
        -not $captureSourceClaims.Contains([string]$_.eventId)
      }).Count -gt 0) {
    Fail 'task 14 has an orphaned or unconsumed capture source command.'
  }
  $steps = @(Require-Property $runReceipt 'steps')
  if ($steps.Count -ne $expectedRunTypes.Count) { Fail 'task 14 run receipt has the wrong setup-step count.' }
  for ($stepIndex = 0; $stepIndex -lt $steps.Count; $stepIndex++) {
    $step = $steps[$stepIndex]
    $eventId = [string](Require-Property $step 'eventId')
    if (-not $eventsById.ContainsKey($eventId)) { Fail "task 14 setup event '$eventId' is missing." }
    $event = $eventsById[$eventId]
    $expectedStepArgv = switch ($stepIndex) {
      0 { $targetPrefix + @('install', '-r', $hapPath) }
      1 { $targetPrefix + @('shell', 'bm', 'clean', '-n', 'com.yuhaofeng.mih', '-d') }
      2 {
        $targetPrefix + @(
          'shell', 'aa', 'start', '-a', 'EntryAbility',
          '-b', 'com.yuhaofeng.mih', '-m', 'entry',
          '--ps', 'runtimeEvidenceRunId', [string]$runReceipt.runId,
          '--ps', 'runtimeEvidenceMode', 'portrait'
        )
      }
      3 { $targetPrefix + @('shell', 'aa', 'dump', '-a') }
      4 { $targetPrefix + @('shell', 'atm', 'dump', '-t', '-b', 'com.yuhaofeng.mih') }
    }
    if ([string](Require-Property $event 'type') -cne $expectedRunTypes[$stepIndex] -or
      [int](Require-Property $event 'exitCode') -ne 0 -or
      [int](Require-Property $step 'exitCode') -ne 0 -or
      (@($event.argv) -join "`0") -cne (@($expectedStepArgv) -join "`0") -or
      [string](Require-Property $step 'eventSha256') -cne
        (Get-TextSha256 ($event | ConvertTo-Json -Compress -Depth 20)) -or
      (($event.device | ConvertTo-Json -Compress) -cne ($device | ConvertTo-Json -Compress))) {
      Fail "task 14 setup event '$eventId' is not hash/device/exit bound."
    }
  }
  $permissionAfterEvents = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'run.permission-after'
    })
  $permissionGrantedEvents = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'source.permission.state-after'
    })
  $permissionDialogCapture = @($captureEvents | Where-Object {
      [string]$_.captureName -ceq 'permission-dialog' -and
      [string]$_.stateName -ceq 'initial'
    })
  $initialPortraitCapture = @($captureEvents | Where-Object {
      [string]$_.captureName -ceq 'initial' -and [string]$_.stateName -ceq 'initial'
    })
  $initialCommands = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'command' -and [string]$_.stateName -ceq 'initial'
    })
  $permissionFirstSource = if ($permissionDialogCapture.Count -eq 1) {
    $eventsById[[string]@($permissionDialogCapture[0].sourceCommandEventIds)[0]]
  } else { $null }
  $permissionLastSource = if ($permissionDialogCapture.Count -eq 1) {
    $ids = @($permissionDialogCapture[0].sourceCommandEventIds)
    $eventsById[[string]$ids[-1]]
  } else { $null }
  $initialFirstSource = if ($initialPortraitCapture.Count -eq 1) {
    $eventsById[[string]@($initialPortraitCapture[0].sourceCommandEventIds)[0]]
  } else { $null }
  $permissionWaitEvents = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'source.permission.wait-aa'
    })
  $permissionGrantedPath = Join-Path $manifestDirectory 'permission-granted.json'
  if ($permissionGrantedEvents.Count -ne 1 -or $permissionDialogCapture.Count -ne 1 -or
    $initialPortraitCapture.Count -ne 1 -or $initialCommands.Count -ne 2 -or
    $null -eq $permissionFirstSource -or $null -eq $permissionLastSource -or
    $null -eq $initialFirstSource -or $permissionWaitEvents.Count -lt 1 -or
    $permissionWaitEvents.Count -gt 40 -or
    @($permissionWaitEvents | Where-Object {
        [int]$_.timeoutMilliseconds -lt 1 -or [int]$_.timeoutMilliseconds -gt 10000
      }).Count -gt 0 -or
    [string]$initialCommands[1].controlId -cne 'system-camera-permission-allow' -or
    [string]$permissionGrantedEvents[0].stateName -cne 'initial' -or
    @($permissionWaitEvents | Where-Object { [string]$_.stateName -cne 'initial' }).Count -gt 0 -or
    [int]$initialCommands[0].sequence -ge [int]$permissionWaitEvents[0].sequence -or
    [int]$permissionWaitEvents[-1].sequence -ge [int]$permissionFirstSource.sequence -or
    [int]$permissionLastSource.sequence -ge [int]$initialCommands[1].sequence -or
    [int]$initialCommands[1].sequence -ge [int]$permissionGrantedEvents[0].sequence -or
    [int]$permissionGrantedEvents[0].sequence -ge [int]$initialFirstSource.sequence -or
    -not [IO.File]::Exists($permissionGrantedPath) -or
    -not (Test-PathInside $permissionGrantedPath $manifestDirectory) -or
    [IO.File]::ReadAllText($permissionGrantedPath) -cne
      [string]$permissionGrantedEvents[0].stdout) {
    Fail 'task 14 camera permission UI grant evidence is missing, reordered, or unbound.'
  }
  $permissionWaitBeforeFinal = if ($permissionWaitEvents.Count -gt 1) {
    @($permissionWaitEvents[0..($permissionWaitEvents.Count - 2)])
  } else { @() }
  $permissionFinalReady =
    Test-SystemPermissionForeground ([string]$permissionWaitEvents[-1].stdout)
  if (@($permissionWaitBeforeFinal | Where-Object {
        Test-SystemPermissionForeground ([string]$_.stdout)
      }).Count -gt 0 -or -not $permissionFinalReady) {
    Fail 'task 14 permission readiness poll does not terminate on the first foreground system dialog.'
  }
  $permissionAa = [IO.File]::ReadAllText([string]$permissionDialogCapture[0].foregroundAaPath)
  if (-not (Test-SystemPermissionForeground $permissionAa)) {
    Fail 'task 14 camera permission capture is not the foreground system privacy dialog.'
  }
  [void](Get-SystemCameraPermissionTarget ([string]$permissionDialogCapture[0].layoutPath))
  try { $permissionGrantedProof = [IO.File]::ReadAllText($permissionGrantedPath) | ConvertFrom-Json }
  catch { Fail 'task 14 camera permission post-click state is not JSON.' }
  $permissionGrantedByName = @{}
  foreach ($entry in @($permissionGrantedProof.permStateList)) {
    $permissionGrantedByName[[string]$entry.permissionName] = [int]$entry.grantStatus
  }
  $permissionGrantedCameraEntries = @($permissionGrantedProof.permStateList | Where-Object {
      [string]$_.permissionName -ceq 'ohos.permission.CAMERA'
    })
  $permissionGrantedMediaEntries = @($permissionGrantedProof.permStateList | Where-Object {
      [string]$_.permissionName -ceq 'ohos.permission.READ_IMAGEVIDEO'
    })
  if ([string]$permissionGrantedProof.bundleName -cne 'com.yuhaofeng.mih' -or
    $permissionGrantedCameraEntries.Count -ne 1 -or
    $permissionGrantedMediaEntries.Count -ne 1 -or
    $permissionGrantedByName['ohos.permission.CAMERA'] -ne 0 -or
    $permissionGrantedByName['ohos.permission.READ_IMAGEVIDEO'] -ne -1) {
    Fail 'task 14 system dialog must grant CAMERA only.'
  }
  $saveDialogCapture = @($captureEvents | Where-Object {
      [string]$_.captureName -ceq 'save-dialog' -and
      [string]$_.stateName -ceq 'save-success'
    })
  $saveCommands = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'command' -and [string]$_.stateName -ceq 'save-success'
    })
  $saveWaitEvents = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'source.save-dialog.wait-aa'
    })
  $firstMediaAfter = @($transcriptLines | Where-Object {
      [string]$_.type -ceq 'source.media.after.level0' -and
      [string]$_.stateName -ceq 'save-success'
    } | Select-Object -First 1)
  $saveFirstSource = if ($saveDialogCapture.Count -eq 1) {
    $eventsById[[string]@($saveDialogCapture[0].sourceCommandEventIds)[0]]
  } else { $null }
  $saveLastSource = if ($saveDialogCapture.Count -eq 1) {
    $ids = @($saveDialogCapture[0].sourceCommandEventIds)
    $eventsById[[string]$ids[-1]]
  } else { $null }
  if ($saveDialogCapture.Count -ne 1 -or $saveCommands.Count -ne 2 -or
    $saveWaitEvents.Count -lt 1 -or $saveWaitEvents.Count -gt 40 -or
    $firstMediaAfter.Count -ne 1 -or $null -eq $saveFirstSource -or
    $null -eq $saveLastSource -or
    @($saveWaitEvents | Where-Object {
        [string]$_.stateName -cne 'save-success' -or
        [int]$_.timeoutMilliseconds -lt 1 -or [int]$_.timeoutMilliseconds -gt 10000
      }).Count -gt 0 -or
    [string]$saveCommands[0].controlId -cne 'portrait-save' -or
    [string]$saveCommands[1].controlId -cne 'system-photo-save-allow' -or
    [int]$saveCommands[0].sequence -ge [int]$saveWaitEvents[0].sequence -or
    [int]$saveWaitEvents[-1].sequence -ge [int]$saveFirstSource.sequence -or
    [int]$saveLastSource.sequence -ge [int]$saveCommands[1].sequence -or
    [int]$saveCommands[1].sequence -ge [int]$firstMediaAfter[0].sequence) {
    Fail 'task 14 photo-save permission evidence is missing, reordered, or unbound.'
  }
  $saveWaitBeforeFinal = if ($saveWaitEvents.Count -gt 1) {
    @($saveWaitEvents[0..($saveWaitEvents.Count - 2)])
  } else { @() }
  $saveWaitReady = Test-SystemPhotoSaveForeground ([string]$saveWaitEvents[-1].stdout)
  $saveCaptureReady = Test-SystemPhotoSaveForeground (
    [IO.File]::ReadAllText([string]$saveDialogCapture[0].foregroundAaPath)
  )
  if (@($saveWaitBeforeFinal | Where-Object {
        Test-SystemPhotoSaveForeground ([string]$_.stdout)
      }).Count -gt 0 -or
    -not $saveWaitReady -or -not $saveCaptureReady) {
    Fail 'task 14 photo-save readiness/capture is not the first foreground reviewed system dialog.'
  }
  [void](Get-SystemPhotoSaveTarget ([string]$saveDialogCapture[0].layoutPath))
  $permissionBeforeEvent = $eventsById[[string]$steps[-1].eventId]
  $expectedPermissionArgv =
    $targetPrefix + @('shell', 'atm', 'dump', '-t', '-b', 'com.yuhaofeng.mih')
  if ($permissionAfterEvents.Count -ne 1 -or
    (@($permissionAfterEvents[0].argv) -join "`0") -cne
      (@($expectedPermissionArgv) -join "`0") -or
    [string]$permissionAfterEvents[0].stateName -cne 'save-success' -or
    [IO.Path]::GetFullPath($permissionProofPaths.permissionBefore) -ine
      [IO.Path]::GetFullPath((Join-Path $manifestDirectory 'permission-before.json')) -or
    [IO.Path]::GetFullPath($permissionProofPaths.permissionAfter) -ine
      [IO.Path]::GetFullPath((Join-Path $manifestDirectory 'permission-after.json')) -or
    [IO.File]::ReadAllText($permissionProofPaths.permissionBefore) -cne
      [string]$permissionBeforeEvent.stdout -or
    [IO.File]::ReadAllText($permissionProofPaths.permissionAfter) -cne
      [string]$permissionAfterEvents[0].stdout) {
    Fail 'task 14 permission proofs are not exact runner HDC before/after captures.'
  }
  if ([int]$manifest.permissionBefore.camera -ne -1 -or
    [int]$manifest.permissionBefore.media -ne -1 -or
    [int]$manifest.permissionAfter.camera -ne 0 -or
    [int]$manifest.permissionAfter.media -ne -1) {
    Fail 'task 14 permission proof must show clean -1/-1 then CAMERA-only 0/-1.'
  }

  $runStateHashes = @(Require-Property $runReceipt 'stateReceiptSha256')
  if ($runStateHashes.Count -ne $contracts.Count -or
    [string](Require-Property $runReceipt 'stateChainRootSha256') -cne
      [string]$runStateHashes[-1]) {
    Fail 'task 14 run receipt has an invalid ordered state chain.'
  }
  $previousHash = ''
  $previousAfter = $null
  $lastRangeEnd = -1
  $currentResultId = ''
  $currentResultHash = ''
  $failedRequestId = ''
  $screenshotOwners = @{}
  for ($sequence = 0; $sequence -lt $contracts.Count; $sequence++) {
    $contract = $contracts[$sequence]
    $state = @($states | Where-Object { [string]$_.name -ceq $contract.Name })[0]
    if ($null -eq $state -or $stateData[$contract.Name].EvidenceStatus -ne 'captured' -or
      $stateData[$contract.Name].CaptureSource -ne 'harness') {
      Fail "task 14 harness evidence is missing captured state '$($contract.Name)'."
    }
    $receiptPath = [string](Require-Property $state 'hdcActionReceiptPath')
    $receiptHash = [string](Require-Property $state 'hdcActionReceiptSha256')
    Require-AbsoluteFile $receiptPath "task 14 state '$($contract.Name)' receipt"
    if (-not (Test-PathInside $receiptPath $manifestDirectory) -or
      $receiptHash -cne (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant() -or
      $receiptHash -cne [string]$runStateHashes[$sequence]) {
      Fail "task 14 state '$($contract.Name)' receipt is not manifest/run hash-bound."
    }
    try { $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json } catch {
      Fail "task 14 state '$($contract.Name)' receipt must be valid UTF-8 JSON."
    }
    $bindings = Require-Property $receipt 'bindings'
    if ([string](Require-Property $receipt 'runId') -cne $runId -or
      [int](Require-Property $receipt 'sequence') -ne $sequence -or
      [string](Require-Property $receipt 'stateName') -cne $contract.Name -or
      [string](Require-Property $receipt 'predecessorState') -cne $contract.Pred -or
      [string](Require-Property $receipt 'previousReceiptSha256') -cne $previousHash -or
      [string](Require-Property $receipt 'actionType') -cne $contract.Action -or
      [string](Require-Property $bindings 'hapSha256') -cne $actualHapHash -or
      [string](Require-Property $bindings 'candidateDiffSha256') -cne $candidateHash -or
      [string](Require-Property $bindings 'candidateIdentitySha256') -cne $candidateIdentitySha256 -or
      [string](Require-Property $bindings 'gitHead') -cne $headSha -or
      [string](Require-Property $bindings 'routeName') -cne $routeName -or
      [double](Require-Property $bindings 'fontScale') -ne $fontScale) {
      Fail "task 14 state '$($contract.Name)' receipt breaks run/sequence/chain/candidate binding."
    }
    $before = Require-Property $receipt 'before'
    $after = Require-Property $receipt 'after'
    $receiptCaptures = @($before, $after)
    for ($receiptCaptureIndex = 0; $receiptCaptureIndex -lt 2; $receiptCaptureIndex++) {
      $capture = $receiptCaptures[$receiptCaptureIndex]
      foreach ($kind in @('layout', 'screenshot')) {
        $path = [string](Require-Property $capture "${kind}Path")
        Require-AbsoluteFile $path "task 14 state '$($contract.Name)' $kind"
        if (-not (Test-PathInside $path $manifestDirectory) -or
          [string](Require-Property $capture "${kind}Sha256") -cne
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()) {
          Fail "task 14 state '$($contract.Name)' $kind is outside/unbound."
        }
      }
      $boundCaptureId = [string](Require-Property $capture 'captureEventId')
      if (-not $eventsById.ContainsKey($boundCaptureId) -or
        [string]$eventsById[$boundCaptureId].type -cne 'capture') {
        Fail "task 14 state '$($contract.Name)' receipt capture event is missing."
      }
      $boundCapture = $eventsById[$boundCaptureId]
      $expectedCaptureState = if ($receiptCaptureIndex -eq 1 -or
        [string]::IsNullOrEmpty($contract.Pred)) {
        $contract.Name
      } else {
        $contract.Pred
      }
      $expectedCaptureName = if ($receiptCaptureIndex -eq 0 -and
        [string]::IsNullOrEmpty($contract.Pred)) {
        'launcher'
      } else {
        $expectedCaptureState
      }
      if ([string]$boundCapture.stateName -cne $expectedCaptureState -or
        [string](Require-Property $boundCapture 'captureName') -cne $expectedCaptureName -or
        [IO.Path]::GetFullPath([string]$capture.layoutPath) -ine
          [IO.Path]::GetFullPath([string]$boundCapture.layoutPath) -or
        [string]$capture.layoutSha256 -cne [string]$boundCapture.layoutSha256 -or
        [IO.Path]::GetFullPath([string]$capture.screenshotPath) -ine
          [IO.Path]::GetFullPath([string]$boundCapture.screenshotPath) -or
        [string]$capture.screenshotSha256 -cne [string]$boundCapture.screenshotSha256) {
        Fail "task 14 state '$($contract.Name)' receipt is not bound to its exact capture event."
      }
      Assert-Task14CaptureEvent $boundCapture $eventsById $targetPrefix $manifestDirectory
    }
    if ([IO.Path]::GetFullPath([string]$after.layoutPath) -ine $stateData[$contract.Name].LayoutPath -or
      [IO.Path]::GetFullPath([string]$after.screenshotPath) -ine $stateData[$contract.Name].ScreenshotPath -or
      ($null -ne $previousAfter -and (
        [IO.Path]::GetFullPath([string]$before.layoutPath) -ine
          [IO.Path]::GetFullPath([string]$previousAfter.layoutPath) -or
        [IO.Path]::GetFullPath([string]$before.screenshotPath) -ine
          [IO.Path]::GetFullPath([string]$previousAfter.screenshotPath)
      ))) {
      Fail "task 14 state '$($contract.Name)' before/after capture lineage is broken."
    }
    if ($contract.Name -notin @('rear-camera', 'reentry') -and
      [string]$before.layoutSha256 -ceq [string]$after.layoutSha256) {
      Fail "task 14 state '$($contract.Name)' must have distinct before/after layouts."
    }
    $afterScreenshotHash = [string]$after.screenshotSha256
    if ($screenshotOwners.ContainsKey($afterScreenshotHash)) {
      $pair = "$($screenshotOwners[$afterScreenshotHash])>$($contract.Name)"
      if ($pair -notin @('preset-selected>custom-background-cancel', 'rear-camera>reentry')) {
        Fail "task 14 state '$($contract.Name)' reuses an unrelated state screenshot."
      }
    } else {
      $screenshotOwners[$afterScreenshotHash] = $contract.Name
    }
    if ([IO.File]::ReadAllText([string]$after.layoutPath) -cmatch [regex]::Escape($contract.Name)) {
      Fail "task 14 state '$($contract.Name)' uses a synthetic state-name layout marker."
    }
    if ($contract.Intermediate) {
      $intermediate = Require-Property $receipt 'intermediate'
      $captureEventId = [string](Require-Property $intermediate 'captureEventId')
      if (-not $eventsById.ContainsKey($captureEventId) -or
        [string]$eventsById[$captureEventId].type -cne 'picker.capture' -or
        [string]$eventsById[$captureEventId].stateName -cne $contract.Name) {
        Fail 'task 14 picker intermediate is not a runner transcript capture event.'
      }
      $pickerCaptureEvent = $eventsById[$captureEventId]
      Assert-Task14CaptureEvent $pickerCaptureEvent $eventsById $targetPrefix $manifestDirectory
      foreach ($field in @('screenshot', 'foregroundAa', 'layoutDumpOutcome')) {
        $path = [string](Require-Property $intermediate "${field}Path")
        Require-AbsoluteFile $path "task 14 picker intermediate $field"
        if (-not (Test-PathInside $path $manifestDirectory) -or
          [string](Require-Property $intermediate "${field}Sha256") -cne
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -or
          [IO.Path]::GetFullPath($path) -ine
            [IO.Path]::GetFullPath([string](Require-Property $pickerCaptureEvent "${field}Path")) -or
          [string](Require-Property $intermediate "${field}Sha256") -cne
            [string](Require-Property $pickerCaptureEvent "${field}Sha256")) {
          Fail 'task 14 picker intermediate capture/foreground is outside or unbound.'
        }
      }
      $layoutAvailable = [bool](Require-Property $intermediate 'layoutAvailable')
      if ($layoutAvailable) {
        $layoutPath = [string](Require-Property $intermediate 'layoutPath')
        Require-AbsoluteFile $layoutPath 'task 14 picker intermediate layout'
        if ([string](Require-Property $intermediate 'layoutSha256') -cne
          (Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
          Fail 'task 14 picker layout is not hash-bound.'
        }
      } elseif ([string](Require-Property $intermediate 'layoutPath') -ne '' -or
        [string](Require-Property $intermediate 'layoutSha256') -ne '') {
        Fail 'task 14 picker zero-byte layout is not bound to the signed dump outcome.'
      }
      if ([IO.File]::ReadAllText([string]$intermediate.foregroundAaPath) -notmatch
        '(?s)com\.ohos\.medialibrary\.medialibrarydata.{0,200}#FOREGROUND') {
        Fail 'task 14 picker cancellation lacks a foreground picker capture.'
      }
    } elseif ($receipt.PSObject.Properties.Name -contains 'intermediate') {
      Fail "task 14 state '$($contract.Name)' has an unexpected intermediate capture."
    }
    $range = Require-Property $receipt 'transcriptRange'
    $rangeStart = [int](Require-Property $range 'start')
    $rangeLength = [int](Require-Property $range 'length')
    if ($rangeStart -lt 0 -or $rangeLength -le 0 -or
      $rangeStart + $rangeLength -gt $transcriptBytes.Length -or
      ($sequence -eq 0 -and $rangeStart -ne $setupByteEnd) -or
      ($lastRangeEnd -ge 0 -and $rangeStart -ne $lastRangeEnd)) {
      Fail "task 14 state '$($contract.Name)' transcript byte range is invalid or reordered."
    }
    $segmentBytes = [byte[]]::new($rangeLength)
    [Array]::Copy($transcriptBytes, $rangeStart, $segmentBytes, 0, $rangeLength)
    if ([string](Require-Property $range 'sha256') -cne (Get-BytesSha256 $segmentBytes)) {
      Fail "task 14 state '$($contract.Name)' transcript segment hash is invalid."
    }
    try {
      $segmentEvents = @($utf8Strict.GetString($segmentBytes).TrimEnd("`r", "`n") -split "`r?`n" |
          ForEach-Object { $_ | ConvertFrom-Json })
    } catch {
      Fail "task 14 state '$($contract.Name)' transcript segment is not JSONL."
    }
    if (@($segmentEvents | Where-Object {
          [string]$_.runId -cne $runId -or [string]$_.stateName -cne $contract.Name
        }).Count -gt 0) {
      Fail "task 14 state '$($contract.Name)' transcript segment is copied from another run/state."
    }
    $commands = @(Require-Property $receipt 'commands')
    $segmentCommands = @($segmentEvents | Where-Object { [string]$_.type -ceq 'command' })
    if ($commands.Count -ne @($contract.Controls).Count -or
      $segmentCommands.Count -ne $commands.Count) {
      Fail "task 14 state '$($contract.Name)' has the wrong production command count."
    }
    for ($commandIndex = 0; $commandIndex -lt $commands.Count; $commandIndex++) {
      $command = $commands[$commandIndex]
      $sourceCommand = $segmentCommands[$commandIndex]
      if (($command | ConvertTo-Json -Compress -Depth 20) -cne
        ($sourceCommand | ConvertTo-Json -Compress -Depth 20) -or
        [string]::IsNullOrWhiteSpace([string](Require-Property $command 'stdout')) -or
        $command.PSObject.Properties.Name -notcontains 'stderr' -or
        [bool](Require-Property $command 'timedOut') -or
        [int](Require-Property $command 'timeoutMilliseconds') -le 0 -or
        [int](Require-Property $command 'exitCode') -ne 0) {
        Fail "task 14 state '$($contract.Name)' command/stdout/stderr/exit lacks transcript provenance."
      }
      try {
        $commandStarted = [datetime]::Parse([string](Require-Property $command 'startedUtc')).ToUniversalTime()
        $commandEnded = [datetime]::Parse([string](Require-Property $command 'endedUtc')).ToUniversalTime()
      } catch {
        Fail "task 14 state '$($contract.Name)' command timestamps are invalid."
      }
      if ($commandStarted -ge $commandEnded -or
        [string](Require-Property $command 'nonce') -notmatch [regex]::Escape($runId)) {
        Fail "task 14 state '$($contract.Name)' command timestamps/nonce are invalid."
      }
      $expectedControl = [string]@($contract.Controls)[$commandIndex]
      $argv = @(Require-Property $command 'argv')
      $targetId = [string]$device.transportId
      if ($expectedControl -eq 'key:Back') {
        if ([string](Require-Property $command 'key') -cne '2' -or
          ($argv -join "`0") -cne
            (@('-t', $targetId, 'shell', 'uitest', 'uiInput', 'keyEvent', '2') -join "`0")) {
          Fail "task 14 state '$($contract.Name)' must issue Back at command $commandIndex."
        }
        continue
      }
      $target = Require-Property $command 'target'
      $targetLayout = [string](Require-Property $target 'layoutPath')
      Require-AbsoluteFile $targetLayout "task 14 state '$($contract.Name)' target layout"
      $targetCaptureId = [string](Require-Property $target 'captureEventId')
      if (-not (Test-PathInside $targetLayout $manifestDirectory) -or
        -not $eventsById.ContainsKey($targetCaptureId) -or
        [string]$eventsById[$targetCaptureId].type -notin @('capture', 'picker.capture') -or
        [IO.Path]::GetFullPath([string]$eventsById[$targetCaptureId].layoutPath) -ine
          [IO.Path]::GetFullPath($targetLayout) -or
        [string](Require-Property $target 'controlId') -cne $expectedControl -or
        [string](Require-Property $target 'layoutSha256') -cne
          (Get-FileHash -LiteralPath $targetLayout -Algorithm SHA256).Hash.ToLowerInvariant()) {
        Fail "task 14 state '$($contract.Name)' command targets the wrong stable production control."
      }
      if ($expectedControl -eq 'system-camera-permission-allow') {
        $targetCapture = $eventsById[$targetCaptureId]
        if ([string]$targetCapture.captureName -cne 'permission-dialog' -or
          [string](Require-Property $target 'selector') -cne
            'structural:system-permission-dialog/allow-button' -or
          [string](Require-Property $target 'ancestorKey') -cne
            'pages/permissionGrantDialog/PermissionGrantDialog' -or
          [string](Require-Property $target 'systemBundle') -cne
            'com.huawei.hmos.security.privacycenter' -or
          [string](Require-Property $target 'permissionName') -cne
            'ohos.permission.CAMERA') {
          Fail 'task 14 camera permission command is not bound to the reviewed system dialog.'
        }
        $systemTarget = Get-SystemCameraPermissionTarget $targetLayout
        $permissionImage = [Drawing.Image]::FromFile([string]$targetCapture.rawScreenshotPath)
        try {
          if ($systemTarget.Bounds.Left -lt 0 -or $systemTarget.Bounds.Top -lt 0 -or
            $systemTarget.Bounds.Right -gt $permissionImage.Width -or
            $systemTarget.Bounds.Bottom -gt $permissionImage.Height) {
            Fail 'task 14 camera permission target bounds are outside the signed screenshot.'
          }
        } finally { $permissionImage.Dispose() }
        $x = [int](Require-Property $target 'x')
        $y = [int](Require-Property $target 'y')
        if ([string](Require-Property $target 'bounds') -cne $systemTarget.BoundsText -or
          $x -ne [int](($systemTarget.Bounds.Left + $systemTarget.Bounds.Right) / 2) -or
          $y -ne [int](($systemTarget.Bounds.Top + $systemTarget.Bounds.Bottom) / 2) -or
          ($argv -join "`0") -cne
            (@('-t', $targetId, 'shell', 'uitest', 'uiInput', 'click', "$x", "$y") -join "`0")) {
          Fail 'task 14 camera permission click misses the signed structural Allow target.'
        }
        continue
      }
      if ($expectedControl -eq 'system-photo-save-allow') {
        $targetCapture = $eventsById[$targetCaptureId]
        if ([string]$targetCapture.captureName -cne 'save-dialog' -or
          [string](Require-Property $target 'selector') -cne
            'structural:system-photo-save-dialog/allow-button' -or
          [string](Require-Property $target 'ancestorKey') -cne 'SaveUIExtensionAbility' -or
          [string](Require-Property $target 'systemBundle') -cne 'com.huawei.hmos.photos' -or
          -not (Test-SystemPhotoSaveForeground (
              [IO.File]::ReadAllText([string]$targetCapture.foregroundAaPath)))) {
          Fail 'task 14 photo-save command is not bound to the reviewed system dialog.'
        }
        $systemTarget = Get-SystemPhotoSaveTarget $targetLayout
        $saveImage = [Drawing.Image]::FromFile([string]$targetCapture.rawScreenshotPath)
        try {
          if ($systemTarget.Bounds.Left -lt 0 -or $systemTarget.Bounds.Top -lt 0 -or
            $systemTarget.Bounds.Right -gt $saveImage.Width -or
            $systemTarget.Bounds.Bottom -gt $saveImage.Height) {
            Fail 'task 14 photo-save target bounds are outside the signed screenshot.'
          }
        } finally { $saveImage.Dispose() }
        $x = [int](Require-Property $target 'x')
        $y = [int](Require-Property $target 'y')
        if ([string](Require-Property $target 'bounds') -cne $systemTarget.BoundsText -or
          $x -ne [int](($systemTarget.Bounds.Left + $systemTarget.Bounds.Right) / 2) -or
          $y -ne [int](($systemTarget.Bounds.Top + $systemTarget.Bounds.Bottom) / 2) -or
          ($argv -join "`0") -cne
            (@('-t', $targetId, 'shell', 'uitest', 'uiInput', 'click', "$x", "$y") -join "`0")) {
          Fail 'task 14 photo-save click misses the signed structural Allow target.'
        }
        continue
      }
      try { $targetTree = Get-Content -LiteralPath $targetLayout -Raw -Encoding utf8 | ConvertFrom-Json } catch {
        Fail "task 14 state '$($contract.Name)' target layout is invalid."
      }
      $selector = [string](Require-Property $target 'selector')
      if ($expectedControl -eq 'portrait-background-strip-swipe') {
        if ($selector -cne 'structural:portrait-background-strip/horizontal-swipe') {
          Fail 'task 14 Custom reveal does not target the reviewed background strip.'
        }
        $bounds = Parse-Bounds ([string](Require-Property $target 'bounds'))
        $startX = [int](Require-Property $target 'startX')
        $startY = [int](Require-Property $target 'startY')
        $endX = [int](Require-Property $target 'endX')
        $endY = [int](Require-Property $target 'endY')
        $velocity = [int](Require-Property $target 'velocity')
        if (($argv -join "`0") -cne (@(
              '-t', $targetId, 'shell', 'uitest', 'uiInput', 'swipe',
              "$startX", "$startY", "$endX", "$endY", "$velocity"
            ) -join "`0") -or
          $startX -le $endX -or $velocity -ne 500 -or
          $startX -lt $bounds.Left -or $startX -gt $bounds.Right -or
          $endX -lt $bounds.Left -or $endX -gt $bounds.Right -or
          $startY -lt $bounds.Top -or $startY -gt $bounds.Bottom -or
          $endY -lt $bounds.Top -or $endY -gt $bounds.Bottom) {
          Fail 'task 14 Custom reveal swipe is outside the bound strip or has wrong argv.'
        }
        continue
      }
      if ($expectedControl -in @('portrait-switch-camera', 'portrait-save')) {
        $pairs = @(Find-ToolbarPairs $targetTree)
        $expectedNode = if ($pairs.Count -eq 1 -and $expectedControl -eq 'portrait-save') {
          $pairs[0].Save
        } elseif ($pairs.Count -eq 1) {
          $pairs[0].Camera
        } else { $null }
        $expectedSelector = if ($expectedControl -eq 'portrait-save') {
          'structural:portrait-toolbar/save-button'
        } else {
          'structural:portrait-toolbar/save-button/previous-clickable-row'
        }
        if ($null -eq $expectedNode -or $selector -cne $expectedSelector -or
          (Attr $expectedNode 'bounds') -cne [string](Require-Property $target 'bounds') -or
          @($pairs[0].Ancestors | Where-Object {
              (Attr $_ 'key') -ceq '/hms/PortraitSegmentationActivity' -or
              (Attr $_ 'pagePath') -ceq '/hms/PortraitSegmentationActivity'
            }).Count -ne 1) {
          Fail 'task 14 toolbar structural selector is not the unique SaveButton/camera sibling pair.'
        }
        $bounds = Parse-Bounds (Attr $expectedNode 'bounds')
        $x = [int](Require-Property $target 'x')
        $y = [int](Require-Property $target 'y')
        if (($argv -join "`0") -cne
          (@('-t', $targetId, 'shell', 'uitest', 'uiInput', 'click', "$x", "$y") -join "`0") -or
          $x -ne [int](($bounds.Left + $bounds.Right) / 2) -or
          $y -ne [int](($bounds.Top + $bounds.Bottom) / 2)) {
          Fail 'task 14 toolbar click misses its structural target.'
        }
        continue
      }
      $matches = @(Find-NodesWithAncestors $targetTree $selector)
      $expectedAncestor = if ($expectedControl -eq 'harness-portrait-route') {
        'pages/RuntimeHarnessPage'
      } else {
        '/hms/PortraitSegmentationActivity'
      }
      $clickableNode = if ($matches.Count -eq 1 -and
        (Attr $matches[0].Node 'clickable') -ceq 'true') {
        $matches[0].Node
      } elseif ($matches.Count -eq 1) {
        @($matches[0].Ancestors | Where-Object { (Attr $_ 'clickable') -ceq 'true' } |
            Select-Object -Last 1)[0]
      } else { $null }
      if ($matches.Count -ne 1 -or $null -eq $clickableNode -or
        [string](Require-Property $target 'ancestorKey') -cne $expectedAncestor -or
        @($matches[0].Ancestors | Where-Object {
            (Attr $_ 'key') -ceq $expectedAncestor -or (Attr $_ 'pagePath') -ceq $expectedAncestor
          }).Count -ne 1 -or
        (Attr $clickableNode 'bounds') -cne [string](Require-Property $target 'bounds')) {
        Fail "task 14 state '$($contract.Name)' selector is a decoy or has wrong production ancestry."
      }
      $bounds = Parse-Bounds (Attr $clickableNode 'bounds')
      $x = [int](Require-Property $target 'x')
      $y = [int](Require-Property $target 'y')
      if (($argv -join "`0") -cne
          (@('-t', $targetId, 'shell', 'uitest', 'uiInput', 'click', "$x", "$y") -join "`0") -or
        $x -ne [int](($bounds.Left + $bounds.Right) / 2) -or
        $y -ne [int](($bounds.Top + $bounds.Bottom) / 2)) {
        Fail "task 14 state '$($contract.Name)' command misses its production control."
      }
    }
    $appRuntimeTypes = @(
      'camera.position.observed', 'camera.restore', 'service.failure', 'service.success'
    )
    $runtimeEvents = @($segmentEvents | Where-Object {
        [string]$_.type -in $appRuntimeTypes
      })
    if ((@($runtimeEvents | ForEach-Object { [string]$_.type }) -join ',') -cne
      (@($contract.Events) -join ',') -or
      (@($runtimeEvents | ForEach-Object { [string]$_.eventId }) -join ',') -cne
      (@((Require-Property $receipt 'runtimeEventIds')) -join ',')) {
      Fail "task 14 state '$($contract.Name)' runtime events do not match its ordered contract."
    }
    $oldHilogEvents = @($segmentEvents | Where-Object { [string]$_.type -ceq 'source.hilog' })
    $hilogPollEvents = @($segmentEvents | Where-Object {
        [string]$_.type -ceq 'source.hilog.poll'
      })
    if ($oldHilogEvents.Count -gt 0) {
      Fail "task 14 state '$($contract.Name)' contains the obsolete source.hilog event."
    }
    foreach ($pollEvent in $hilogPollEvents) {
      if ([string]$pollEvent.stateName -cne $contract.Name -or
        (@($pollEvent.argv) -join "`0") -cne
          (@($targetPrefix + @('shell', 'hilog', '-x', '-T', 'MIH_RUNTIME_EVIDENCE')) -join "`0") -or
        (@((Require-Property $pollEvent 'expectedTypes')) -join ',') -cne
          (@($contract.Events) -join ',')) {
        Fail "task 14 state '$($contract.Name)' hilog poll argv/state/contract is invalid."
      }
    }
    foreach ($runtimeEvent in $runtimeEvents) {
      $sourceEventId = [string](Require-Property $runtimeEvent 'sourceCommandEventId')
      if (-not $eventsById.ContainsKey($sourceEventId) -or
        [string]$eventsById[$sourceEventId].type -cne 'source.hilog.poll' -or
        [string]$eventsById[$sourceEventId].stateName -cne $contract.Name -or
        [int]$eventsById[$sourceEventId].sequence -ge [int]$runtimeEvent.sequence -or
        [string]$runtimeEvent.utc -cne [string]$eventsById[$sourceEventId].endedUtc -or
        [string](Require-Property $runtimeEvent 'rawLineSha256') -notmatch '^[0-9a-f]{64}$') {
        Fail "task 14 state '$($contract.Name)' runtime event is not parsed from raw HDC hilog."
      }
      $sourceEvent = $eventsById[$sourceEventId]
      $rawLines = @([string]$sourceEvent.stdout -split "`r?`n" | Where-Object {
          $_ -match 'MIH_RUNTIME_EVENT \{.*\}' -and
          (Get-BytesSha256 $utf8Strict.GetBytes($_)) -ceq [string]$runtimeEvent.rawLineSha256
        })
      if ($rawLines.Count -ne 1) {
        Fail "task 14 state '$($contract.Name)' runtime event has no unique raw HDC hilog line."
      }
      try {
        if ($rawLines[0] -notmatch 'MIH_RUNTIME_EVENT (?<payload>\{.*\})') {
          throw 'missing marker'
        }
        $rawPayload = $Matches.payload | ConvertFrom-Json
      } catch {
        Fail "task 14 state '$($contract.Name)' runtime event raw HDC hilog payload is invalid."
      }
      if ($rawPayload.PSObject.Properties.Name -contains 'utc' -or
        $rawPayload.PSObject.Properties.Name -contains 'stateName') {
        Fail "task 14 state '$($contract.Name)' app payload self-reports runner-owned fields."
      }
      foreach ($property in $rawPayload.PSObject.Properties) {
        if ($runtimeEvent.PSObject.Properties.Name -cnotcontains $property.Name -or
          ($runtimeEvent.$($property.Name) | ConvertTo-Json -Compress -Depth 20) -cne
          ($property.Value | ConvertTo-Json -Compress -Depth 20)) {
          Fail "task 14 state '$($contract.Name)' runtime event differs from raw HDC hilog."
        }
      }
    }
    $runtimeByType = @{}
    foreach ($runtimeEvent in $runtimeEvents) {
      if (-not $runtimeByType.ContainsKey([string]$runtimeEvent.type)) {
        $runtimeByType[[string]$runtimeEvent.type] = @()
      }
      $runtimeByType[[string]$runtimeEvent.type] += $runtimeEvent
    }
    if ($contract.Name -in @('rear-camera', 'reentry') -and
      @($runtimeEvents | Where-Object { [string]$_.cameraPosition -cne 'back' }).Count -gt 0) {
      Fail "task 14 state '$($contract.Name)' camera events do not prove rear position/restore."
    }
    if ($contract.Name -eq 'transient-failure') {
      $failure = $runtimeByType['service.failure'][0]
      if ([string]$failure.errorCode -cne 'SEGMENTATION_FAILED' -or
        [string]::IsNullOrWhiteSpace([string]$failure.preservedResultFingerprint)) {
        Fail 'task 14 transient failure lacks the reviewed service error and prior harness result fingerprint.'
      }
    }
    if ($contract.Name -eq 'retry-success') {
      $success = $runtimeByType['service.success'][0]
      if ([string]::IsNullOrWhiteSpace([string]$success.resultFingerprint)) {
        Fail 'task 14 Retry success lacks a fingerprint from the reviewed harness result.'
      }
    }
    if ($contract.Name -eq 'save-success') {
      $mediaAssets = @($segmentEvents | Where-Object { [string]$_.type -ceq 'media.asset' })
      if ($mediaAssets.Count -ne 1) { Fail 'task 14 Save must produce exactly one physical media asset.' }
      $asset = $mediaAssets[0]
      $localPath = [string](Require-Property $asset 'localPath')
      Require-AbsoluteFile $localPath 'task 14 saved JPEG'
      $bytes = [IO.File]::ReadAllBytes($localPath)
      try {
        Add-Type -AssemblyName System.Drawing
        $decodedImage = [Drawing.Image]::FromFile($localPath)
        try {
          if ($decodedImage.Width -le 0 -or $decodedImage.Height -le 0 -or
            $decodedImage.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Jpeg.Guid) {
            Fail 'task 14 saved media is not a decodable JPEG.'
          }
        } finally {
          $decodedImage.Dispose()
        }
      } catch {
        Fail 'task 14 saved media is not a decodable JPEG.'
      }
      $beforeMedia = @($segmentEvents | Where-Object { [string]$_.type -like 'source.media.before.level*' })
      $afterMedia = @($segmentEvents | Where-Object { [string]$_.type -like 'source.media.after.level*' })
      $mediaExport = @($segmentEvents | Where-Object { [string]$_.type -ceq 'source.media.export' })
      $mediaRecv = @($segmentEvents | Where-Object { [string]$_.type -ceq 'source.media.recv' })
      $mediaPath = [string](Require-Property $asset 'mediaPath')
      $beforeSnapshots = @(Convert-Task14MediaSnapshots $beforeMedia 'before' $targetPrefix)
      $afterSnapshots = @(Convert-Task14MediaSnapshots $afterMedia 'after' $targetPrefix)
      if ($beforeSnapshots.Count -ne 1 -or $afterSnapshots.Count -lt 3) {
        Fail 'task 14 Save media proof lacks one before and three settled after snapshots.'
      }
      $beforeEntries = @($beforeSnapshots[0].Entries)
      $beforePaths = @($beforeEntries | Where-Object { -not $_.IsDirectory } |
          ForEach-Object { $_.Path } | Sort-Object -Unique)
      $stablePath = ''
      $stableSize = 0L
      $stableObservations = 0
      foreach ($afterSnapshot in $afterSnapshots) {
        $snapshotFiles = @($afterSnapshot.Entries | Where-Object { -not $_.IsDirectory })
        $snapshotPaths = @($snapshotFiles | ForEach-Object { $_.Path } | Sort-Object -Unique)
        $addedPaths = @($snapshotPaths | Where-Object { $beforePaths -cnotcontains $_ })
        if ($addedPaths.Count -gt 1) {
          Fail 'task 14 Save media snapshot contains more than one new path.'
        }
        if ($addedPaths.Count -eq 0) {
          $stablePath = ''
          $stableSize = 0L
          $stableObservations = 0
          continue
        }
        $candidatePath = [string]$addedPaths[0]
        $candidateEntries = @($snapshotFiles | Where-Object {
            [string]$_.Path -ceq $candidatePath
          })
        $candidateSize = [long]$candidateEntries[0].Size
        if ($candidateSize -le 0 -or
          @($candidateEntries | Where-Object {
              [long]$_.Size -ne $candidateSize
            }).Count -gt 0) {
          Fail 'task 14 Save media snapshot contains an empty or inconsistent file.'
        }
        if ($candidatePath -ceq $stablePath -and $candidateSize -eq $stableSize) {
          $stableObservations++
        } else {
          $stablePath = $candidatePath
          $stableSize = $candidateSize
          $stableObservations = 1
        }
      }
      if (-not (Test-PathInside $localPath $manifestDirectory) -or
        [long](Require-Property $asset 'mediaSize') -le 0 -or
        [long]$asset.mediaSize -ne [long]$bytes.Length -or
        $mediaPath -notmatch
          '^/storage/media/100/local/files/Photo/' -or
        $beforeMedia.Count -lt 1 -or $afterMedia.Count -lt 1 -or
        $stableObservations -lt 3 -or $stablePath -cne $mediaPath -or
        $stableSize -ne [long]$asset.mediaSize -or
        $mediaExport.Count -ne 1 -or $mediaRecv.Count -ne 1 -or
        (@($mediaExport[0].argv)[-5..-1] -join "`0") -cne
          (@('shell', 'mediatool', 'recv', $mediaPath,
              "/data/local/tmp/task14-$runId-saved.jpg") -join "`0") -or
        (@($mediaRecv[0].argv)[-4..-1] -join "`0") -cne
          (@('file', 'recv', "/data/local/tmp/task14-$runId-saved.jpg", $localPath) -join "`0") -or
        [string](Require-Property $asset 'localSha256') -cne
          (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash.ToLowerInvariant() -or
        $bytes.Length -le 4 -or $bytes[0] -ne 0xff -or $bytes[1] -ne 0xd8 -or
        $bytes[$bytes.Length - 2] -ne 0xff -or $bytes[$bytes.Length - 1] -ne 0xd9) {
        Fail 'task 14 Save media asset path/size/hash/JPEG proof is invalid.'
      }
    }
    $previousHash = $receiptHash
    $previousAfter = $after
    $lastRangeEnd = $rangeStart + $rangeLength
  }
  if ([string]$runReceipt.stateChainRootSha256 -cne $previousHash -or
    $lastRangeEnd -ne $transcriptBytes.Length) {
    Fail 'task 14 final state chain/transcript EOF does not close.'
  }

  $scopeDiff = Normalize-Text (
    (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      diff --ignore-cr-at-eol --ignore-space-at-eol --unified=0 HEAD -- 2>$null) -join "`n"
  )
  $changedPaths = @([regex]::Matches($scopeDiff, '(?m)^\+\+\+ b/(.+)$') |
      ForEach-Object { $_.Groups[1].Value })
  $allowedPathPattern =
    '(^|/)entry/src/main/ets/entryability/EntryAbility\.ets$|' +
    '(^|/)entry/src/main/ets/pages/FeatureRuntimePage\.ets$|' +
    '(^|/)entry/src/main/ets/.*/RuntimeHarness[^/]*\.ets$|' +
    '(^|/)entry/src/main/resources/base/profile/main_pages\.json$'
  if (@($changedPaths | Where-Object { $_ -notmatch $allowedPathPattern }).Count -gt 0) {
    Fail 'task 14 harness candidate changes files outside the reviewed harness surface.'
  }
  $runtimeHarnessPaths = @($changedPaths | Where-Object { $_ -match 'RuntimeHarness' })
  $expectedRuntimeHarnessPaths = @(
    ($gitPathPrefix.Replace('\', '/') + 'entry/src/main/ets/pages/RuntimeHarnessPage.ets'),
    ($gitPathPrefix.Replace('\', '/') + 'entry/src/main/ets/runtime/RuntimeHarnessAdapter.ets')
  )
  if ($runtimeHarnessPaths.Count -ne 2 -or
    @($runtimeHarnessPaths | Where-Object {
        $expectedRuntimeHarnessPaths -cnotcontains $_
      }).Count -gt 0) {
    Fail 'task 14 harness candidate contains an unreviewed RuntimeHarness source file.'
  }
  $featurePath = Join-Path $repositoryRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $featureGitPath = ($gitPathPrefix.Replace('\', '/') +
      'entry/src/main/ets/pages/FeatureRuntimePage.ets')
  if (-not [IO.File]::Exists($featurePath)) {
    Fail 'task 14 protected FeatureRuntimePage is missing.'
  }
  $featureHead = Normalize-Text (
    (& git -c core.autocrlf=false -c core.safecrlf=false -C $resolvedGitRoot `
        show "HEAD`:$featureGitPath" 2>$null) -join "`n"
  )
  if ($LASTEXITCODE -ne 0) { Fail 'task 14 protected FeatureRuntimePage is absent from HEAD.' }
  $featureCurrent = Normalize-Text ([IO.File]::ReadAllText($featurePath))
  $protectedFeatureMethods = @(
    'applyAiResult',
    'refreshLiveCameraSwitchAvailability', 'autoStartLiveCameraIfNeeded',
    'startLiveCameraPreview', 'startLiveCameraPreviewAsync',
    'stopLiveCameraPreview', 'stopLiveCameraPreviewAsync', 'switchLiveCamera',
    'liveObjectDetectionRetryAction', 'retryLiveObjectDetection',
    'liveClassificationRetryAction', 'liveSegmentationRetryAction',
    'liveGestureRetryAction', 'liveSceneRetryAction', 'liveSkeletonRetryAction',
    'retryLiveGesture', 'retryLiveScene',
    'retryLiveSkeleton', 'retryLiveClassification',
    'showRuntimeToast', 'showStillSegmentationFailureToastIfNeeded',
    'saveResultImage', 'saveResultComponentImage', 'saveResultPixelMap',
    'saveStyleTransferResultImage', 'saveStyleTransferResultImageAsync',
    'saveStillSegmentationResultImage', 'saveStillSegmentationResultImageAsync',
    'saveResultComponentImageAsync', 'saveResultPixelMapAsync', 'performResultPixelMapSave',
    'liveCameraSurfaceContent', 'liveCameraPreview', 'runtimeCameraSwitchAction',
    'resultImageSaveControl', 'resultComponentImageSaveControl',
    'portraitSegmentationBackgroundGrid', 'portraitSegmentationBackgroundItem',
    'portraitSegmentationCustomBackgroundItem', 'portraitSegmentationToolbar',
    'portraitSegmentationComposite', 'portraitSegmentationStatus',
    'portraitSegmentationBackgroundStrip', 'portraitSegmentationAndroidLayout'
  )
  foreach ($methodName in $protectedFeatureMethods) {
    $headBlock = Get-ArkTsMethodBlock $featureHead $methodName $false
    if ($null -eq $headBlock) { continue }
    $currentBlock = Get-ArkTsMethodBlock $featureCurrent $methodName $true
    if ((Get-TextSha256 $headBlock) -cne (Get-TextSha256 $currentBlock)) {
      Fail "task 14 harness candidate modifies protected FeatureRuntimePage method '$methodName'."
    }
  }
  $hookBlocks = @{
    aboutToAppear = @('RuntimeHarnessAdapter.fromParams(params)', 'RUNTIME_UI_HARNESS_ROUTE_HOOK_BEGIN')
    runWorkflowAsync = @(
      'const frameInputReady = this.runtimeHarnessAdapter !== undefined ||',
      'RUNTIME_UI_HARNESS_FRAME_HOOK_BEGIN',
      'runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs())',
      'RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN'
    )
    applyLiveCameraPreviewResult = @('runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition)',
      'RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN')
    retryLiveSegmentation = @('runtimeHarnessAdapter?.allowRetry()',
      'RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN')
  }
  foreach ($hookMethod in $hookBlocks.Keys) {
    $block = Get-ArkTsMethodBlock $featureCurrent $hookMethod $true
    foreach ($needle in @($hookBlocks[$hookMethod])) {
      if (@([regex]::Matches($block, [regex]::Escape($needle))).Count -ne 1) {
        Fail "task 14 reviewed hook is missing or misplaced in '$hookMethod'."
      }
    }
  }
  $routeHook = Get-ArkTsMethodBlock $featureCurrent 'aboutToAppear' $true
  $routeParamsIndex = $routeHook.IndexOf(
    'const params = router.getParams() as FeatureRuntimeParams;',
    [StringComparison]::Ordinal
  )
  $routeAdapterIndex = $routeHook.IndexOf(
    'this.runtimeHarnessAdapter = RuntimeHarnessAdapter.fromParams(params);',
    [StringComparison]::Ordinal
  )
  if ($routeParamsIndex -lt 0 -or $routeAdapterIndex -le $routeParamsIndex) {
    Fail 'task 14 route adapter must be created after the real router params read.'
  }
  $serviceHeadBlock = Get-ArkTsMethodBlock $featureHead 'runWorkflowAsync' $true
  $serviceBlock = Get-ArkTsMethodBlock $featureCurrent 'runWorkflowAsync' $true
  $realRun = 'await aiService.run(workflow, this.aiRunInputs())'
  $serviceBegin = $serviceBlock.IndexOf('RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN',
    [StringComparison]::Ordinal)
  $serviceEnd = $serviceBlock.IndexOf('RUNTIME_UI_HARNESS_SERVICE_HOOK_END',
    [StringComparison]::Ordinal)
  $frameBegin = $serviceBlock.IndexOf('RUNTIME_UI_HARNESS_FRAME_HOOK_BEGIN',
    [StringComparison]::Ordinal)
  $frameEnd = $serviceBlock.IndexOf('RUNTIME_UI_HARNESS_FRAME_HOOK_END',
    [StringComparison]::Ordinal)
  $frameGuardIndex = $serviceBlock.IndexOf('if (!frameInputReady)',
    [StringComparison]::Ordinal)
  $tryIndex = $serviceBlock.IndexOf('try {', [StringComparison]::Ordinal)
  $catchIndex = $serviceBlock.LastIndexOf('catch', [StringComparison]::Ordinal)
  if (@([regex]::Matches($serviceHeadBlock, [regex]::Escape($realRun))).Count -ne 1 -or
    @([regex]::Matches($serviceBlock, [regex]::Escape($realRun))).Count -ne 1 -or
    $tryIndex -lt 0 -or $frameBegin -le $tryIndex -or $frameEnd -le $frameBegin -or
    $frameGuardIndex -le $frameEnd -or $serviceBegin -le $frameGuardIndex -or
    $serviceEnd -le $serviceBegin -or $catchIndex -le $serviceEnd) {
    Fail 'task 14 frame/service adapters must remain ordered inside the real try/catch.'
  }
  $cameraBlock = Get-ArkTsMethodBlock $featureCurrent 'applyLiveCameraPreviewResult' $true
  $cameraGuardIndex = $cameraBlock.IndexOf('if (!result.ok)', [StringComparison]::Ordinal)
  $cameraGuardReturnIndex = $cameraBlock.IndexOf(
    'return;',
    $cameraGuardIndex,
    [StringComparison]::Ordinal
  )
  $cameraPostGuardIndex = $cameraBlock.LastIndexOf(
    'this.pendingPickTextInputVisible = undefined;',
    [StringComparison]::Ordinal
  )
  $cameraHookIndex = $cameraBlock.IndexOf(
    'this.runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition);',
    [StringComparison]::Ordinal
  )
  $cameraRunIndex = $cameraBlock.IndexOf(
    'shouldAutoRunLiveRuntimeAfterPreview',
    [StringComparison]::Ordinal
  )
  if ($cameraGuardIndex -lt 0 -or $cameraGuardReturnIndex -le $cameraGuardIndex -or
    $cameraPostGuardIndex -le $cameraGuardReturnIndex -or
    $cameraHookIndex -le $cameraPostGuardIndex -or $cameraRunIndex -le $cameraHookIndex) {
    Fail 'task 14 camera observer must remain after the failure guard and before auto-run.'
  }
  $retryBlock = Get-ArkTsMethodBlock $featureCurrent 'retryLiveSegmentation' $true
  $retryActionIndex = $retryBlock.IndexOf(
    "if (action !== 'restartInference')",
    [StringComparison]::Ordinal
  )
  $retryHookIndex = $retryBlock.IndexOf(
    'this.runtimeHarnessAdapter?.allowRetry();',
    [StringComparison]::Ordinal
  )
  $retryGuardReturnIndex = $retryBlock.IndexOf(
    'return;',
    $retryActionIndex,
    [StringComparison]::Ordinal
  )
  $retryTriggers = @([regex]::Matches(
      $retryBlock,
      'this\.(?:startLiveRuntimeLoop\(workflow\)|startLiveCameraPreview\(\));'
    ) | Where-Object { $_.Index -gt $retryGuardReturnIndex })
  $retryTriggerIndex = if ($retryTriggers.Count -gt 0) { $retryTriggers[0].Index } else { -1 }
  if ($retryActionIndex -lt 0 -or $retryGuardReturnIndex -le $retryActionIndex -or
    $retryHookIndex -le $retryGuardReturnIndex -or
    $retryTriggerIndex -le $retryHookIndex) {
    Fail 'task 14 retry gate must remain after action validation and before the real run trigger.'
  }
  $canonicalTransforms = @(
    [pscustomobject]@{
      Name = 'aboutToAppear'
      Needle = "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_BEGIN`n" +
        "    this.runtimeHarnessAdapter = RuntimeHarnessAdapter.fromParams(params);`n" +
        "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_END`n"
      Replacement = ''
    },
    [pscustomobject]@{
      Name = 'runWorkflowAsync'
      Needle = "      // RUNTIME_UI_HARNESS_FRAME_HOOK_BEGIN`n" +
        "      const frameInputReady = this.runtimeHarnessAdapter !== undefined ||`n" +
        "        await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);`n" +
        "      // RUNTIME_UI_HARNESS_FRAME_HOOK_END"
      Replacement =
        '      const frameInputReady = await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);'
    },
    [pscustomobject]@{
      Name = 'runWorkflowAsync'
      Needle = "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN`n" +
        "      const result: AiRunResult = this.runtimeHarnessAdapter === undefined ?`n" +
        "        await aiService.run(workflow, this.aiRunInputs()) :`n" +
        "        await this.runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs());`n" +
        "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_END"
      Replacement =
        '      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());'
    },
    [pscustomobject]@{
      Name = 'applyLiveCameraPreviewResult'
      Needle = "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN`n" +
        "    this.runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition);`n" +
        "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_END`n"
      Replacement = ''
    },
    [pscustomobject]@{
      Name = 'retryLiveSegmentation'
      Needle = "    // RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN`n" +
        "    this.runtimeHarnessAdapter?.allowRetry();`n" +
        "    // RUNTIME_UI_HARNESS_RETRY_HOOK_END`n"
      Replacement = ''
    }
  )
  foreach ($methodTransforms in @($canonicalTransforms | Group-Object Name)) {
    $methodName = [string]$methodTransforms.Name
    $headMethod = Get-ArkTsMethodBlock $featureHead $methodName $true
    $restoredMethod = Get-ArkTsMethodBlock $featureCurrent $methodName $true
    foreach ($transform in @($methodTransforms.Group)) {
      if (@([regex]::Matches(
            $restoredMethod,
            [regex]::Escape([string]$transform.Needle)
          )).Count -ne 1) {
        Fail "task 14 canonical hook block in '$methodName' is not exact."
      }
      $restoredMethod = $restoredMethod.Replace(
        [string]$transform.Needle,
        [string]$transform.Replacement
      )
    }
    if ((Get-TextSha256 $restoredMethod) -cne (Get-TextSha256 $headMethod)) {
      Fail "task 14 '$methodName' is not HEAD plus only its canonical hook transforms."
    }
  }
  $featureSection = [regex]::Match(
    $scopeDiff,
    '(?ms)^diff --git[^\r\n]*?/FeatureRuntimePage\.ets[^\r\n]*\r?\n.*?(?=^diff --git |\z)'
  ).Value
  $featureChangedLines = @($featureSection -split "`n" | Where-Object {
      $_ -match '^[+-](?![+-])'
    })
  # The only reviewed FeatureRuntimePage hook is a harness-local adapter selected from
  # router params and substituted at the existing service-result boundary. Require the
  # complete, marker-delimited patch with each exact line once; partial/ad-hoc hunks fail.
  $allowedFeatureChangedLines = @(
    "+import { RuntimeHarnessAdapter } from '../runtime/RuntimeHarnessAdapter';",
    '+  private runtimeHarnessAdapter: RuntimeHarnessAdapter | undefined = undefined;',
    '+    // RUNTIME_UI_HARNESS_ROUTE_HOOK_BEGIN',
    '+    this.runtimeHarnessAdapter = RuntimeHarnessAdapter.fromParams(params);',
    '+    // RUNTIME_UI_HARNESS_ROUTE_HOOK_END',
    '-      const frameInputReady = await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);',
    '+      // RUNTIME_UI_HARNESS_FRAME_HOOK_BEGIN',
    '+      const frameInputReady = this.runtimeHarnessAdapter !== undefined ||',
    '+        await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);',
    '+      // RUNTIME_UI_HARNESS_FRAME_HOOK_END',
    '-      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());',
    '+      // RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN',
    '+      const result: AiRunResult = this.runtimeHarnessAdapter === undefined ?',
    '+        await aiService.run(workflow, this.aiRunInputs()) :',
    '+        await this.runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs());',
    '+      // RUNTIME_UI_HARNESS_SERVICE_HOOK_END',
    '+    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN',
    '+    this.runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition);',
    '+    // RUNTIME_UI_HARNESS_CAMERA_HOOK_END',
    '+    // RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN',
    '+    this.runtimeHarnessAdapter?.allowRetry();',
    '+    // RUNTIME_UI_HARNESS_RETRY_HOOK_END'
  )
  if ($featureChangedLines.Count -ne $allowedFeatureChangedLines.Count -or
    @($featureChangedLines | Where-Object {
        $allowedFeatureChangedLines -cnotcontains $_
      }).Count -gt 0) {
    $unexpectedFeatureLines = @($featureChangedLines | Where-Object {
        $allowedFeatureChangedLines -cnotcontains $_
      })
    Fail "task 14 harness candidate contains an unreviewed FeatureRuntimePage hunk: $(
      $unexpectedFeatureLines -join ' | '
    )"
  }
  foreach ($allowedLine in $allowedFeatureChangedLines) {
    if (@($featureChangedLines | Where-Object { $_ -ceq $allowedLine }).Count -ne 1) {
      Fail 'task 14 harness candidate does not contain the exact reviewed FeatureRuntimePage hook.'
    }
  }
  $adapterPath = Join-Path $repositoryRoot `
    'entry\src\main\ets\runtime\RuntimeHarnessAdapter.ets'
  Require-AbsoluteFile $adapterPath 'task 14 runtime harness adapter'
  $adapterTemplatePath = Join-Path $producerTemplateRoot 'RuntimeHarnessAdapter.ets'
  Require-AbsoluteFile $adapterTemplatePath 'trusted runtime harness adapter template'
  $adapterSource = Normalize-Text ([IO.File]::ReadAllText($adapterPath))
  if ($scopeDiff -notmatch
      "(?m)^\+\+\+ b/${diffPathPrefix}entry/src/main/ets/runtime/RuntimeHarnessAdapter\.ets$" -or
    $adapterSource -cne (Normalize-Text ([IO.File]::ReadAllText($adapterTemplatePath)))) {
    Fail 'task 14 runtime harness adapter has an unreviewed UI-mutation or result/event surface.'
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
