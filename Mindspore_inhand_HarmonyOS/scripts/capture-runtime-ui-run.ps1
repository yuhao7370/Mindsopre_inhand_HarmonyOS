param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{32}$')][string]$RunId,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
  [Parameter(Mandatory = $true)][string]$HapPath,
  [Parameter(Mandatory = $true)][string]$HdcPath,
  [string]$BundleName = 'com.yuhaofeng.mih',
  [string]$AbilityName = 'EntryAbility'
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)

function Fail([string]$Message) { throw "Runtime evidence capture failed: $Message" }

function Get-Sha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Get-FileSha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Quote-ProcessArgument([string]$Value) {
  if ($Value -notmatch '[\s"]' -and $Value.Length -gt 0) { return $Value }
  $builder = [Text.StringBuilder]::new()
  [void]$builder.Append('"')
  $slashes = 0
  foreach ($character in $Value.ToCharArray()) {
    if ($character -eq '\') { $slashes++; continue }
    if ($character -eq '"') {
      [void]$builder.Append(('\' * ($slashes * 2 + 1)))
      [void]$builder.Append('"')
    } else {
      if ($slashes -gt 0) { [void]$builder.Append(('\' * $slashes)) }
      [void]$builder.Append($character)
    }
    $slashes = 0
  }
  if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
  [void]$builder.Append('"')
  return $builder.ToString()
}

function New-Nonce([int]$Sequence) {
  return "$RunId`:$($Sequence.ToString('D6')):$([guid]::NewGuid().ToString('N'))"
}

function Add-TranscriptEvent([Collections.IDictionary]$Event) {
  $script:eventSequence++
  $Event.sequence = $script:eventSequence
  $Event.captureRunnerSha256 = $script:runnerHash
  if (-not $Event.Contains('nonce')) { $Event.nonce = New-Nonce $script:eventSequence }
  $Event.previousLineSha256 = $script:previousLineHash
  $line = ($Event | ConvertTo-Json -Compress -Depth 20) + "`n"
  [IO.File]::AppendAllText(
    $OutputPath,
    $line,
    $utf8
  )
  $script:previousLineHash = Get-Sha256 $utf8.GetBytes($line)
}

function Invoke-Hdc(
  [string]$Type,
  [string[]]$Argv,
  [string]$StateName = '',
  [Collections.IDictionary]$Extra = $null,
  [bool]$AllowFailure = $false,
  [int]$TimeoutMilliseconds = 300000
) {
  if ($TimeoutMilliseconds -le 0) { Fail "HDC '$Type' timeout must be positive." }
  $started = [datetime]::UtcNow
  $startedTicks = [Diagnostics.Stopwatch]::GetTimestamp()
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $HdcPath
  $startInfo.Arguments = (@($Argv | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.StandardOutputEncoding = $utf8
  $startInfo.StandardErrorEncoding = $utf8
  $startInfo.EnvironmentVariables['RUNTIME_EVIDENCE_RUN_ID'] = $RunId
  $startInfo.EnvironmentVariables['RUNTIME_EVIDENCE_STATE'] = $StateName
  $startInfo.EnvironmentVariables['RUNTIME_EVIDENCE_DIRECTORY'] = $EvidenceDirectory
  $startInfo.EnvironmentVariables['RUNTIME_EVIDENCE_CAPTURE_NAME'] = [string]$script:captureName
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  $timedOut = $false
  $stdout = ''
  $stderr = ''
  $exitCode = -1
  try {
    if (-not $process.Start()) { Fail "could not start HDC for '$Type'." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
      $timedOut = $true
      try { $process.Kill() } catch [InvalidOperationException] {}
      $process.WaitForExit()
    } else {
      $process.WaitForExit()
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
  } finally {
    $process.Dispose()
  }
  $ended = [datetime]::UtcNow
  $endedTicks = [Diagnostics.Stopwatch]::GetTimestamp()
  $eventId = "process-$($script:eventSequence + 1)"
  $event = [ordered]@{
    type = $Type
    eventId = $eventId
    runId = $RunId
    utc = $started.ToString('o')
    startedUtc = $started.ToString('o')
    endedUtc = $ended.ToString('o')
    startedMonotonicTicks = $startedTicks
    endedMonotonicTicks = $endedTicks
    executablePath = [IO.Path]::GetFullPath($HdcPath)
    argv = @($Argv)
    stdout = $stdout
    stderr = $stderr
    stdoutSha256 = Get-Sha256 $utf8.GetBytes($stdout)
    stderrSha256 = Get-Sha256 $utf8.GetBytes($stderr)
    exitCode = $exitCode
    timedOut = $timedOut
    timeoutMilliseconds = $TimeoutMilliseconds
  }
  if ($StateName -ne '') { $event.stateName = $StateName }
  if ($null -ne $Extra) {
    foreach ($key in $Extra.Keys) { $event[$key] = $Extra[$key] }
  }
  Add-TranscriptEvent $event
  if ($timedOut) { Fail "HDC '$Type' timed out after $TimeoutMilliseconds ms." }
  if ($exitCode -ne 0 -and -not $AllowFailure) { Fail "HDC '$Type' exited $exitCode`: $stderr" }
  return [pscustomobject]@{
    EventId = $eventId
    Stdout = $stdout
    Stderr = $stderr
    ExitCode = $exitCode
    Started = $started
    Ended = $ended
  }
}

function Write-NewTextFile([string]$Path, [string]$Text) {
  $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
  try {
    $bytes = $utf8.GetBytes($Text)
    $stream.Write($bytes, 0, $bytes.Length)
  } finally {
    $stream.Dispose()
  }
}

function Capture-State([string]$CaptureName, [string]$StateName) {
  $script:captureName = $CaptureName
  $captureRoot = Join-Path $EvidenceDirectory 'runner-captures'
  [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
  $ordinal = ($script:eventSequence + 1).ToString('D4')
  $remoteBase = "/data/local/tmp/task14-$RunId-$ordinal"
  $layoutPath = Join-Path $captureRoot "$CaptureName.json"
  $rawScreenshotPath = Join-Path $captureRoot "$CaptureName.png"
  $screenshotPath = Join-Path $captureRoot "$CaptureName.jpeg"
  $aaPath = Join-Path $captureRoot "$CaptureName-aa.txt"
  $displayPath = Join-Path $captureRoot "$CaptureName-display.txt"
  foreach ($path in @($layoutPath, $rawScreenshotPath, $screenshotPath, $aaPath, $displayPath)) {
    if ([IO.File]::Exists($path)) { Fail "capture output '$path' already exists." }
  }
  $dump = Invoke-Hdc 'source.capture.layout' ($targetPrefix + @(
      'shell', 'uitest', 'dumpLayout', '-p', "$remoteBase.json"
    )) $StateName
  $screen = Invoke-Hdc 'source.capture.screen' ($targetPrefix + @(
      'shell', 'uitest', 'screenCap', '-p', "$remoteBase.png"
    )) $StateName
  $recvLayout = Invoke-Hdc 'source.capture.recv-layout' ($targetPrefix + @(
      'file', 'recv', "$remoteBase.json", $layoutPath
    )) $StateName
  $recvScreen = Invoke-Hdc 'source.capture.recv-screen' ($targetPrefix + @(
      'file', 'recv', "$remoteBase.png", $rawScreenshotPath
    )) $StateName
  if (-not [IO.File]::Exists($layoutPath) -or -not [IO.File]::Exists($rawScreenshotPath)) {
    Fail "HDC capture '$CaptureName' did not create received layout/screenshot files."
  }
  Add-Type -AssemblyName System.Drawing
  $image = [Drawing.Image]::FromFile($rawScreenshotPath)
  try { $image.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Jpeg) } finally { $image.Dispose() }
  $aa = Invoke-Hdc 'source.capture.foreground-aa' ($targetPrefix + @('shell', 'aa', 'dump', '-a')) $StateName
  $display = Invoke-Hdc 'source.capture.display' ($targetPrefix + @(
      'shell', 'hidumper', '-s', 'DisplayManagerService', '-a', '-a'
    )) $StateName
  Write-NewTextFile $aaPath $aa.Stdout
  Write-NewTextFile $displayPath $display.Stdout
  $eventId = "$StateName-capture-$CaptureName"
  $event = [ordered]@{
    type = if ($CaptureName -eq 'picker-intermediate') { 'picker.capture' } else { 'capture' }
    eventId = $eventId
    runId = $RunId
    stateName = $StateName
    utc = $display.Ended.ToString('o')
    captureName = $CaptureName
    sourceCommandEventIds = @(
      $dump.EventId, $screen.EventId, $recvLayout.EventId, $recvScreen.EventId,
      $aa.EventId, $display.EventId
    )
    layoutPath = $layoutPath
    layoutSha256 = Get-FileSha256 $layoutPath
    rawScreenshotPath = $rawScreenshotPath
    rawScreenshotSha256 = Get-FileSha256 $rawScreenshotPath
    screenshotPath = $screenshotPath
    screenshotSha256 = Get-FileSha256 $screenshotPath
    foregroundAaPath = $aaPath
    foregroundAaSha256 = Get-FileSha256 $aaPath
    displayPath = $displayPath
    displaySha256 = Get-FileSha256 $displayPath
  }
  Add-TranscriptEvent $event
  return [pscustomobject]$event
}

function Capture-PickerState([string]$StateName) {
  $script:captureName = 'picker-intermediate'
  $captureRoot = Join-Path $EvidenceDirectory 'runner-captures'
  [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
  $ordinal = ($script:eventSequence + 1).ToString('D4')
  $remoteBase = "/data/local/tmp/task14-$RunId-$ordinal-picker"
  $layoutPath = Join-Path $captureRoot 'picker-intermediate.json'
  $rawScreenshotPath = Join-Path $captureRoot 'picker-intermediate.png'
  $screenshotPath = Join-Path $captureRoot 'picker-intermediate.jpeg'
  $aaPath = Join-Path $captureRoot 'picker-intermediate-aa.txt'
  $dumpOutcomePath = Join-Path $captureRoot 'picker-intermediate-dump-outcome.txt'
  foreach ($path in @($layoutPath, $rawScreenshotPath, $screenshotPath, $aaPath, $dumpOutcomePath)) {
    if ([IO.File]::Exists($path)) { Fail "capture output '$path' already exists." }
  }
  $dump = Invoke-Hdc 'source.picker.layout-attempt' ($targetPrefix + @(
      'shell', 'uitest', 'dumpLayout', '-p', "$remoteBase.json"
    )) $StateName $null $true
  $screen = Invoke-Hdc 'source.picker.screen' ($targetPrefix + @(
      'shell', 'uitest', 'screenCap', '-p', "$remoteBase.png"
    )) $StateName
  $recvLayout = Invoke-Hdc 'source.picker.recv-layout-attempt' ($targetPrefix + @(
      'file', 'recv', "$remoteBase.json", $layoutPath
    )) $StateName $null $true
  $recvScreen = Invoke-Hdc 'source.picker.recv-screen' ($targetPrefix + @(
      'file', 'recv', "$remoteBase.png", $rawScreenshotPath
    )) $StateName
  if (-not [IO.File]::Exists($rawScreenshotPath) -or ([IO.FileInfo]$rawScreenshotPath).Length -le 0) {
    Fail 'picker capture did not produce a screenshot.'
  }
  Add-Type -AssemblyName System.Drawing
  $image = [Drawing.Image]::FromFile($rawScreenshotPath)
  try { $image.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Jpeg) } finally { $image.Dispose() }
  $aa = Invoke-Hdc 'source.picker.foreground-aa' ($targetPrefix + @('shell', 'aa', 'dump', '-a')) $StateName
  Write-NewTextFile $aaPath $aa.Stdout
  $dumpOutcome = "dumpExitCode=$($dump.ExitCode)`ndumpStdout=$($dump.Stdout)`ndumpStderr=$($dump.Stderr)`n" +
    "recvExitCode=$($recvLayout.ExitCode)`nrecvStdout=$($recvLayout.Stdout)`nrecvStderr=$($recvLayout.Stderr)`n"
  Write-NewTextFile $dumpOutcomePath $dumpOutcome
  $layoutAvailable = [IO.File]::Exists($layoutPath) -and ([IO.FileInfo]$layoutPath).Length -gt 0
  $event = [ordered]@{
    type = 'picker.capture'
    eventId = "$StateName-capture-picker-intermediate"
    runId = $RunId
    stateName = $StateName
    utc = $aa.Ended.ToString('o')
    captureName = 'picker-intermediate'
    sourceCommandEventIds = @(
      $dump.EventId, $screen.EventId, $recvLayout.EventId, $recvScreen.EventId, $aa.EventId
    )
    layoutAvailable = $layoutAvailable
    layoutPath = if ($layoutAvailable) { $layoutPath } else { '' }
    layoutSha256 = if ($layoutAvailable) { Get-FileSha256 $layoutPath } else { '' }
    layoutDumpOutcomePath = $dumpOutcomePath
    layoutDumpOutcomeSha256 = Get-FileSha256 $dumpOutcomePath
    rawScreenshotPath = $rawScreenshotPath
    rawScreenshotSha256 = Get-FileSha256 $rawScreenshotPath
    screenshotPath = $screenshotPath
    screenshotSha256 = Get-FileSha256 $screenshotPath
    foregroundAaPath = $aaPath
    foregroundAaSha256 = Get-FileSha256 $aaPath
  }
  Add-TranscriptEvent $event
  return [pscustomobject]$event
}

function Find-ControlNode([object]$Node, [string[]]$Texts, [object[]]$Ancestors = @()) {
  $attributes = $Node.attributes
  $label = if ($null -ne $attributes) {
    @([string]$attributes.text, [string]$attributes.originalText) |
      Where-Object { $_ -ne '' } | Select-Object -First 1
  } else { '' }
  $results = @()
  if ($Texts -contains $label) {
    $clickableNode = $Node
    if ([string]$attributes.clickable -cne 'true') {
      $clickableNode = @($Ancestors | Where-Object {
          [string]$_.attributes.clickable -ceq 'true'
        } | Select-Object -Last 1)[0]
    }
    if ($null -ne $clickableNode) {
      $results += [pscustomobject]@{ LabelNode = $Node; ClickableNode = $clickableNode; Ancestors = $Ancestors }
    }
  }
  if ($null -ne $Node.children) {
    foreach ($child in @($Node.children)) {
      $results += @(Find-ControlNode $child $Texts (@($Ancestors) + @($Node)))
    }
  }
  return $results
}

function Resolve-ControlTarget(
  [object]$Capture,
  [string]$LogicalId,
  [string[]]$Texts,
  [string]$ExpectedAncestor
) {
  try { $layout = Get-Content -LiteralPath $Capture.layoutPath -Raw -Encoding utf8 | ConvertFrom-Json }
  catch { Fail "runner capture '$($Capture.captureName)' layout is invalid JSON." }
  $matches = @(Find-ControlNode $layout $Texts)
  if ($matches.Count -ne 1) { Fail "capture '$($Capture.captureName)' must expose one '$LogicalId' control." }
  $match = $matches[0]
  if (@($match.Ancestors | Where-Object {
        [string]$_.attributes.key -ceq $ExpectedAncestor -or
        [string]$_.attributes.pagePath -ceq $ExpectedAncestor
      }).Count -ne 1) {
    Fail "control '$LogicalId' is outside expected route ancestry '$ExpectedAncestor'."
  }
  $boundsText = [string]$match.ClickableNode.attributes.bounds
  if ($boundsText -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
    Fail "control '$LogicalId' has invalid bounds."
  }
  $left = [int]$Matches[1]; $top = [int]$Matches[2]
  $right = [int]$Matches[3]; $bottom = [int]$Matches[4]
  if ($right -le $left -or $bottom -le $top) { Fail "control '$LogicalId' has empty bounds." }
  return [ordered]@{
    selector = "text:$([string]$match.LabelNode.attributes.text)"
    controlId = $LogicalId
    ancestorKey = $ExpectedAncestor
    bounds = $boundsText
    x = [int](($left + $right) / 2)
    y = [int](($top + $bottom) / 2)
    layoutPath = [string]$Capture.layoutPath
    layoutSha256 = [string]$Capture.layoutSha256
    captureEventId = [string]$Capture.eventId
  }
}

function Resolve-SystemCameraPermissionTarget([object]$Capture) {
  $layoutText = [Text.Encoding]::GetEncoding(28591).GetString(
    [IO.File]::ReadAllBytes([string]$Capture.layoutPath)
  )
  $systemBundle = 'com.huawei.hmos.security.privacycenter'
  $systemPage = 'pages/permissionGrantDialog/PermissionGrantDialog'
  $controlId = 'permission_dialog_allow_button'
  if ([regex]::Matches($layoutText, [regex]::Escape($systemBundle)).Count -ne 1 -or
    [regex]::Matches($layoutText, [regex]::Escape($systemPage)).Count -ne 1) {
    Fail 'camera permission dialog does not expose the reviewed system bundle/page.'
  }
  $attributeObjects = @([regex]::Matches(
      $layoutText,
      '(?s)"attributes"\s*:\s*\{(?<attrs>[^{}]*?"id"\s*:\s*"' +
        [regex]::Escape($controlId) + '"[^{}]*?)\}\s*,\s*"children"'
    ))
  if ($attributeObjects.Count -ne 1) {
    Fail 'camera permission dialog must expose one structural Allow button.'
  }
  $attributes = $attributeObjects[0].Groups['attrs'].Value
  function Permission-Attribute([string]$Name) {
    $matches = @([regex]::Matches(
        $attributes,
        '"' + [regex]::Escape($Name) + '"\s*:\s*"(?<value>[^"]*)"'
      ))
    if ($matches.Count -ne 1) { Fail "camera permission Allow button lacks unique '$Name'." }
    return $matches[0].Groups['value'].Value
  }
  $boundsText = Permission-Attribute 'bounds'
  if ((Permission-Attribute 'key') -cne $controlId -or
    (Permission-Attribute 'type') -cne 'Button' -or
    (Permission-Attribute 'clickable') -cne 'true' -or
    (Permission-Attribute 'enabled') -cne 'true' -or
    (Permission-Attribute 'visible') -cne 'true' -or
    $boundsText -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
    Fail 'camera permission Allow button is not the reviewed visible clickable system control.'
  }
  $left = [int]$Matches[1]; $top = [int]$Matches[2]
  $right = [int]$Matches[3]; $bottom = [int]$Matches[4]
  $image = [Drawing.Image]::FromFile([string]$Capture.rawScreenshotPath)
  try {
    if ($right -le $left -or $bottom -le $top -or
      $left -lt 0 -or $top -lt 0 -or $right -gt $image.Width -or $bottom -gt $image.Height) {
      Fail 'camera permission Allow button bounds are empty or outside the signed screenshot.'
    }
  } finally { $image.Dispose() }
  return [ordered]@{
    selector = 'structural:system-permission-dialog/allow-button'
    controlId = 'system-camera-permission-allow'
    ancestorKey = $systemPage
    systemBundle = $systemBundle
    permissionName = 'ohos.permission.CAMERA'
    bounds = $boundsText
    x = [int](($left + $right) / 2)
    y = [int](($top + $bottom) / 2)
    layoutPath = [string]$Capture.layoutPath
    layoutSha256 = [string]$Capture.layoutSha256
    captureEventId = [string]$Capture.eventId
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

function Wait-SystemCameraPermission([string]$StateName, [int]$TimeoutSeconds = 10) {
  $script:captureName = 'permission-wait'
  $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $remainingMilliseconds = [int][Math]::Floor(($deadline - [datetime]::UtcNow).TotalMilliseconds)
    if ($remainingMilliseconds -le 0) { break }
    $probe = Invoke-Hdc 'source.permission.wait-aa' ($targetPrefix + @(
        'shell', 'aa', 'dump', '-a'
      )) $StateName $null $false ([Math]::Min($remainingMilliseconds, 10000))
    if (Test-SystemPermissionForeground $probe.Stdout) { return }
    Start-Sleep -Milliseconds 300
  } while ([datetime]::UtcNow -lt $deadline)
  Fail 'timed out waiting for the foreground system camera permission dialog.'
}

function Get-BoundsTarget(
  [object]$Node,
  [string]$LogicalId,
  [string]$Selector,
  [string]$ExpectedAncestor,
  [object[]]$Ancestors,
  [object]$Capture
) {
  if (@($Ancestors | Where-Object {
        [string]$_.attributes.key -ceq $ExpectedAncestor -or
        [string]$_.attributes.pagePath -ceq $ExpectedAncestor
      }).Count -ne 1) {
    Fail "control '$LogicalId' is outside expected route ancestry '$ExpectedAncestor'."
  }
  $boundsText = [string]$Node.attributes.bounds
  if ($boundsText -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
    Fail "control '$LogicalId' has invalid bounds."
  }
  $left = [int]$Matches[1]; $top = [int]$Matches[2]
  $right = [int]$Matches[3]; $bottom = [int]$Matches[4]
  if ($right -le $left -or $bottom -le $top) { Fail "control '$LogicalId' has empty bounds." }
  return [ordered]@{
    selector = $Selector
    controlId = $LogicalId
    ancestorKey = $ExpectedAncestor
    bounds = $boundsText
    x = [int](($left + $right) / 2)
    y = [int](($top + $bottom) / 2)
    layoutPath = [string]$Capture.layoutPath
    layoutSha256 = [string]$Capture.layoutSha256
    captureEventId = [string]$Capture.eventId
  }
}

function Find-ToolbarStructuralTargets([object]$Node, [object[]]$Ancestors = @()) {
  $results = @()
  $children = @($Node.children)
  for ($index = 0; $index -lt $children.Count; $index++) {
    $child = $children[$index]
    if ([string]$child.attributes.type -ceq 'SaveButton') {
      $previous = if ($index -gt 0) { $children[$index - 1] } else { $null }
      if ($null -ne $previous -and
        [string]$previous.attributes.clickable -ceq 'true' -and
        [string]$previous.attributes.type -ceq 'Row') {
        $results += [pscustomobject]@{
          Save = $child
          Camera = $previous
          Ancestors = @($Ancestors) + @($Node)
        }
      }
    }
  }
  foreach ($child in $children) {
    $results += @(Find-ToolbarStructuralTargets $child (@($Ancestors) + @($Node)))
  }
  return $results
}

function Resolve-ToolbarTarget(
  [object]$Capture,
  [string]$LogicalId,
  [bool]$SaveTarget
) {
  try { $layout = Get-Content -LiteralPath $Capture.layoutPath -Raw -Encoding utf8 | ConvertFrom-Json }
  catch { Fail "runner capture '$($Capture.captureName)' layout is invalid JSON." }
  $matches = @(Find-ToolbarStructuralTargets $layout)
  if ($matches.Count -ne 1) { Fail 'portrait toolbar must expose one SaveButton/camera sibling pair.' }
  $node = if ($SaveTarget) { $matches[0].Save } else { $matches[0].Camera }
  $selector = if ($SaveTarget) {
    'structural:portrait-toolbar/save-button'
  } else {
    'structural:portrait-toolbar/save-button/previous-clickable-row'
  }
  return Get-BoundsTarget $node $LogicalId $selector '/hms/PortraitSegmentationActivity' `
    $matches[0].Ancestors $Capture
}

function Resolve-BackgroundSwipeTarget([object]$Capture) {
  try { $layout = Get-Content -LiteralPath $Capture.layoutPath -Raw -Encoding utf8 | ConvertFrom-Json }
  catch { Fail "runner capture '$($Capture.captureName)' layout is invalid JSON." }
  $presetMatches = @(Find-ControlNode $layout $controlTexts['portrait-preset-2'])
  if ($presetMatches.Count -ne 1) { Fail 'portrait background strip must expose one preset 2 control.' }
  $list = @($presetMatches[0].Ancestors | Where-Object {
      [string]$_.attributes.type -ceq 'List' -or
      [string]$_.attributes.scrollable -ceq 'true'
    } | Select-Object -Last 1)[0]
  if ($null -eq $list) { Fail 'preset 2 is not inside a scrollable background strip.' }
  $target = Get-BoundsTarget $list 'portrait-background-strip-swipe' `
    'structural:portrait-background-strip/horizontal-swipe' `
    '/hms/PortraitSegmentationActivity' $presetMatches[0].Ancestors $Capture
  if ($target.bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
    Fail 'portrait background strip bounds are invalid.'
  }
  $left = [int]$Matches[1]; $top = [int]$Matches[2]
  $right = [int]$Matches[3]; $bottom = [int]$Matches[4]
  $target.startX = [int]($left + (($right - $left) * 0.8))
  $target.endX = [int]($left + (($right - $left) * 0.2))
  $target.startY = [int](($top + $bottom) / 2)
  $target.endY = $target.startY
  $target.velocity = 500
  return $target
}

function Wait-RuntimeEvents(
  [string]$StateName,
  [string[]]$ExpectedTypes,
  [int]$TimeoutSeconds = 20
) {
  if ($ExpectedTypes.Count -eq 0) { return @() }
  $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
  $accepted = [Collections.Generic.List[object]]::new()
  while ([datetime]::UtcNow -lt $deadline) {
    $remainingMilliseconds = [Math]::Max(
      1,
      [int][Math]::Floor(($deadline - [datetime]::UtcNow).TotalMilliseconds)
    )
    $pollTimeoutMilliseconds = [Math]::Min(2000, $remainingMilliseconds)
    $hilog = Invoke-Hdc 'source.hilog.poll' ($targetPrefix + @(
        'shell', 'hilog', '-x', '-T', 'MIH_RUNTIME_EVIDENCE'
      )) $StateName ([ordered]@{ expectedTypes = @($ExpectedTypes) }) $false $pollTimeoutMilliseconds
    if ($hilog.Stdout -match '(?i)Invalid argument') {
      Fail "HDC hilog rejected the Task 14 tag filter for '$StateName'."
    }
    foreach ($line in @($hilog.Stdout -split "`r?`n")) {
      if ($line -notmatch 'MIH_RUNTIME_EVENT (?<json>\{.*\})') { continue }
      try { $payload = $Matches.json | ConvertFrom-Json }
      catch { Fail "invalid runtime event JSON for '$StateName'." }
      $eventId = [string]$payload.eventId
      $type = [string]$payload.type
      if ([string]$payload.runId -cne $RunId -or
        [string]::IsNullOrWhiteSpace($eventId) -or
        $type -notin @(
          'camera.position.observed', 'camera.restore', 'service.failure', 'service.success'
        ) -or $script:seenRuntimeEventIds.Contains($eventId)) {
        continue
      }
      if ($type -notin $ExpectedTypes) { continue }
      if ($type -in @('camera.position.observed', 'camera.restore') -and
        [string]$payload.cameraPosition -cne 'back') {
        continue
      }
      $event = [ordered]@{}
      foreach ($property in $payload.PSObject.Properties) { $event[$property.Name] = $property.Value }
      $event.stateName = $StateName
      $event.utc = $hilog.Ended.ToString('o')
      $event.captureRunnerSha256 = $script:runnerHash
      $event.sourceCommandEventId = $hilog.EventId
      $event.rawLineSha256 = Get-Sha256 $utf8.GetBytes($line)
      $event.nonce = New-Nonce ($script:eventSequence + 1)
      Add-TranscriptEvent $event
      [void]$script:seenRuntimeEventIds.Add($eventId)
      $accepted.Add([pscustomobject]$event)
    }
    if ((@($accepted | ForEach-Object { [string]$_.type }) -join ',') -ceq
      ($ExpectedTypes -join ',')) {
      return $accepted.ToArray()
    }
    $sleepMilliseconds = [Math]::Min(
      500,
      [Math]::Max(0, [int][Math]::Floor(($deadline - [datetime]::UtcNow).TotalMilliseconds))
    )
    if ($sleepMilliseconds -gt 0) { Start-Sleep -Milliseconds $sleepMilliseconds }
  }
  Fail "timed out waiting for runtime events '$($ExpectedTypes -join ',')' in '$StateName'."
}

function Convert-MediaListing([string]$Directory, [string]$Text) {
  $entries = @()
  foreach ($line in @($Text -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed -match '^(No Error|total\s+\d+)') { continue }
    $pathMatch = [regex]::Match($trimmed, '(/storage/media/100/local/files/Photo(?:/[^\s]+)*)\s*$')
    $path = if ($pathMatch.Success) {
      $pathMatch.Groups[1].Value
    } else {
      $name = @($trimmed -split '\s+')[-1].Trim('"')
      if ($name -match '^[./]+$' -or $name.Contains(':')) { continue }
      "$($Directory.TrimEnd('/'))/$name"
    }
    $tokens = @($trimmed -split '\s+')
    $size = 0L
    foreach ($token in $tokens) {
      $parsed = 0L
      if ([long]::TryParse($token, [ref]$parsed)) { $size = $parsed }
    }
    $entries += [pscustomobject]@{
      Path = $path
      Size = $size
      IsDirectory = $trimmed.StartsWith('d')
    }
  }
  return $entries
}

function Get-MediaInventory([string]$StateName, [string]$Phase) {
  $root = '/storage/media/100/local/files/Photo'
  $all = [Collections.Generic.List[object]]::new()
  $directories = @($root)
  for ($depth = 0; $depth -le 2; $depth++) {
    $nextDirectories = [Collections.Generic.List[string]]::new()
    foreach ($directory in @($directories | Sort-Object -Unique)) {
      $listing = Invoke-Hdc "source.media.$Phase.level$depth" ($targetPrefix + @(
          'shell', 'mediatool', 'ls', '-l', $directory
        )) $StateName ([ordered]@{ mediaDirectory = $directory; depth = $depth })
      foreach ($entry in @(Convert-MediaListing $directory $listing.Stdout)) {
        $all.Add($entry)
        if ($entry.IsDirectory -and $depth -lt 2) { $nextDirectories.Add([string]$entry.Path) }
      }
    }
    $directories = $nextDirectories.ToArray()
  }
  $files = @($all | Where-Object { -not $_.IsDirectory } |
      Group-Object Path | ForEach-Object { $_.Group | Select-Object -First 1 })
  return $files
}

function Wait-NewMediaAsset([object[]]$Before, [string]$StateName, [int]$TimeoutSeconds = 30) {
  $beforePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($entry in @($Before)) { [void]$beforePaths.Add([string]$entry.Path) }
  $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
  $stablePath = ''
  $stableSize = 0L
  $stableObservations = 0
  $requiredStableObservations = 3
  while ([datetime]::UtcNow -lt $deadline) {
    $after = @(Get-MediaInventory $StateName 'after')
    $added = @($after | Where-Object { -not $beforePaths.Contains([string]$_.Path) })
    if ($added.Count -gt 1) { Fail 'save created more than one new physical media file.' }
    if ($added.Count -eq 1) {
      if ([long]$added[0].Size -le 0) { Fail 'save created an empty physical media file.' }
      $candidatePath = [string]$added[0].Path
      $candidateSize = [long]$added[0].Size
      if ($candidatePath -ceq $stablePath -and $candidateSize -eq $stableSize) {
        $stableObservations++
      } else {
        $stablePath = $candidatePath
        $stableSize = $candidateSize
        $stableObservations = 1
      }
      if ($stableObservations -ge $requiredStableObservations) {
        return [pscustomobject]@{ Added = $added[0]; After = $after }
      }
    } else {
      $stablePath = ''
      $stableSize = 0L
      $stableObservations = 0
    }
    Start-Sleep -Milliseconds 500
  }
  Fail 'timed out waiting for one new physical media file.'
}

function Receive-MediaAsset([object]$Asset, [string]$StateName) {
  $captureRoot = Join-Path $EvidenceDirectory 'runner-captures'
  [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
  $remoteTemp = "/data/local/tmp/task14-$RunId-saved.jpg"
  $localPath = Join-Path $captureRoot 'save-success-asset.jpg'
  if ([IO.File]::Exists($localPath)) { Fail 'refusing to overwrite saved media evidence.' }
  $mediaRecv = Invoke-Hdc 'source.media.export' ($targetPrefix + @(
      'shell', 'mediatool', 'recv', [string]$Asset.Path, $remoteTemp
    )) $StateName ([ordered]@{ mediaPath = [string]$Asset.Path })
  $fileRecv = Invoke-Hdc 'source.media.recv' ($targetPrefix + @(
      'file', 'recv', $remoteTemp, $localPath
    )) $StateName ([ordered]@{ mediaPath = [string]$Asset.Path; remoteTemp = $remoteTemp })
  if (-not [IO.File]::Exists($localPath) -or ([IO.FileInfo]$localPath).Length -le 4) {
    Fail 'saved media evidence is missing or empty.'
  }
  $bytes = [IO.File]::ReadAllBytes($localPath)
  if ($bytes[0] -ne 0xff -or $bytes[1] -ne 0xd8 -or
    $bytes[$bytes.Length - 2] -ne 0xff -or $bytes[$bytes.Length - 1] -ne 0xd9) {
    Fail 'saved media evidence is not a complete JPEG.'
  }
  $event = [ordered]@{
    type = 'media.asset'
    eventId = "$StateName-media-asset"
    runId = $RunId
    stateName = $StateName
    utc = $fileRecv.Ended.ToString('o')
    mediaPath = [string]$Asset.Path
    mediaSize = [long]$Asset.Size
    localPath = $localPath
    localSha256 = Get-FileSha256 $localPath
    sourceCommandEventIds = @($mediaRecv.EventId, $fileRecv.EventId)
  }
  Add-TranscriptEvent $event
  return [pscustomobject]$event
}

if (-not [IO.Path]::IsPathRooted($OutputPath) -or
  -not [IO.Path]::IsPathRooted($EvidenceDirectory) -or
  -not [IO.Path]::IsPathRooted($HapPath) -or
  -not [IO.Path]::IsPathRooted($HdcPath)) {
  Fail 'all paths must be absolute.'
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
$HapPath = [IO.Path]::GetFullPath($HapPath)
$HdcPath = [IO.Path]::GetFullPath($HdcPath)
if ([IO.File]::Exists($OutputPath)) { Fail 'refusing to overwrite an existing transcript.' }
foreach ($path in @($HapPath, $HdcPath)) {
  if (-not [IO.File]::Exists($path)) { Fail "required input '$path' is missing." }
}
if (-not [IO.Directory]::Exists($EvidenceDirectory)) { Fail 'evidence directory is missing.' }
if (-not $OutputPath.StartsWith($EvidenceDirectory.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) {
  Fail 'transcript must be written inside the evidence directory.'
}

$script:runnerHash = Get-FileSha256 $PSCommandPath
$script:eventSequence = -1
$script:previousLineHash = ('0' * 64)
$script:captureName = ''
$script:seenRuntimeEventIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$stateOrder = @(
  'initial', 'preset-selected', 'custom-background-cancel', 'rear-camera', 'reentry',
  'transient-failure', 'retry-success', 'save-success'
)
$actionArgv = @{
  'initial' = @(
    ,@('shell', 'uitest', 'uiInput', 'click', '0', '0'),
    ,@('shell', 'uitest', 'uiInput', 'click', '0', '0')
  )
  'preset-selected' = @(,@('shell', 'uitest', 'uiInput', 'click', '0', '0'))
  'custom-background-cancel' = @(
    ,@('shell', 'uitest', 'uiInput', 'swipe', '0', '0', '0', '0', '500'),
    ,@('shell', 'uitest', 'uiInput', 'click', '0', '0'),
    ,@('shell', 'uitest', 'uiInput', 'keyEvent', '2')
  )
  'rear-camera' = @(,@('shell', 'uitest', 'uiInput', 'click', '0', '0'))
  'reentry' = @(
    ,@('shell', 'uitest', 'uiInput', 'keyEvent', '2'),
    ,@('shell', 'uitest', 'uiInput', 'click', '0', '0')
  )
  'transient-failure' = @()
  'retry-success' = @(,@('shell', 'uitest', 'uiInput', 'click', '0', '0'))
  'save-success' = @(,@('shell', 'uitest', 'uiInput', 'click', '0', '0'))
}
$controlIds = @{
  'initial' = @('harness-portrait-route', 'system-camera-permission-allow')
  'preset-selected' = @('portrait-preset-2')
  'custom-background-cancel' = @(
    'portrait-background-strip-swipe', 'portrait-custom-background', 'key:Back'
  )
  'rear-camera' = @('portrait-switch-camera')
  'reentry' = @('key:Back', 'harness-portrait-route')
  'transient-failure' = @()
  'retry-success' = @('portrait-retry')
  'save-success' = @('portrait-save')
}
$background2Zh = (-join @(0x80CC, 0x666F | ForEach-Object { [char]$_ })) + ' 2'
$customZh = -join @(0x81EA, 0x5B9A, 0x4E49 | ForEach-Object { [char]$_ })
$switchCameraZh = -join @(0x5207, 0x6362, 0x6444, 0x50CF, 0x5934 | ForEach-Object { [char]$_ })
$retryZh = -join @(0x91CD, 0x8BD5 | ForEach-Object { [char]$_ })
$saveZh = -join @(0x4FDD, 0x5B58 | ForEach-Object { [char]$_ })
$saveImageZh = -join @(0x4FDD, 0x5B58, 0x56FE, 0x7247 | ForEach-Object { [char]$_ })
$controlTexts = @{
  'harness-portrait-route' = @('Open portrait')
  'portrait-preset-2' = @('Background 2', $background2Zh)
  'portrait-custom-background' = @('Custom background', $customZh)
  'portrait-switch-camera' = @('Switch camera', $switchCameraZh)
  'portrait-retry' = @('Retry', $retryZh)
  'portrait-save' = @('Save', $saveZh, $saveImageZh)
}
$expectedRuntimeEventTypes = @{
  'initial' = @()
  'preset-selected' = @()
  'custom-background-cancel' = @()
  'rear-camera' = @('camera.position.observed')
  'reentry' = @('camera.restore')
  'transient-failure' = @('service.failure')
  'retry-success' = @('service.success')
  'save-success' = @()
}

$deviceResult = Invoke-Hdc 'run.device' @('list', 'targets', '-v')
$connectedTargets = @($deviceResult.Stdout -split "`r?`n" | ForEach-Object {
    $fields = @($_ -split "`t" | Where-Object { $_ -ne '' })
    if ($fields.Count -ge 4 -and $fields[2] -ceq 'Connected') {
      [pscustomobject]@{ Fields = $fields }
    }
  })
if ($connectedTargets.Count -ne 1) { Fail 'HDC must report exactly one Connected target.' }
$targetFields = @($connectedTargets[0].Fields)
$target = [string]$targetFields[0]
$device = [ordered]@{
  transportId = $target
  serial = $target
  fingerprint = ($targetFields -join "`t")
  packageFingerprint = "$BundleName`:entry"
}
$targetPrefix = @('-t', $target)
Invoke-Hdc 'run.install' ($targetPrefix + @('install', '-r', $HapPath)) -Extra ([ordered]@{ device = $device }) | Out-Null
Invoke-Hdc 'run.clean-data' ($targetPrefix + @(
    'shell', 'bm', 'clean', '-n', $BundleName, '-d'
  )) -Extra ([ordered]@{ device = $device }) | Out-Null
Invoke-Hdc 'run.start' ($targetPrefix + @(
    'shell', 'aa', 'start', '-a', $AbilityName, '-b', $BundleName, '-m', 'entry',
    '--ps', 'runtimeEvidenceRunId', $RunId,
    '--ps', 'runtimeEvidenceMode', 'portrait'
  )) -Extra ([ordered]@{ device = $device }) | Out-Null
Invoke-Hdc 'run.foreground-aa' ($targetPrefix + @('shell', 'aa', 'dump', '-a')) -Extra ([ordered]@{ device = $device }) | Out-Null
$permissionBefore = Invoke-Hdc 'run.permission-before' ($targetPrefix + @(
    'shell', 'atm', 'dump', '-t', '-b', $BundleName
  )) -Extra ([ordered]@{ device = $device })
Write-NewTextFile (Join-Path $EvidenceDirectory 'permission-before.json') $permissionBefore.Stdout

$currentCapture = Capture-State 'launcher' 'initial'
foreach ($stateName in $stateOrder) {
  $mediaBefore = if ($stateName -eq 'save-success') {
    @(Get-MediaInventory $stateName 'before')
  } else {
    @()
  }
  $argvList = @($actionArgv[$stateName])
  $inputResults = @()
  for ($index = 0; $index -lt $argvList.Count; $index++) {
    $argvValue = $argvList[$index]
    while ($argvValue -is [array] -and $argvValue.Count -eq 1 -and $argvValue[0] -is [array]) {
      $argvValue = $argvValue[0]
    }
    $argv = [string[]]$argvValue
    $controlId = [string]@($controlIds[$stateName])[$index]
    $extra = [ordered]@{ inputIndex = $index; controlId = $controlId }
    if ($controlId -eq 'key:Back') {
      $extra.key = '2'
    } elseif ($controlId -eq 'portrait-background-strip-swipe') {
      $targetInfo = Resolve-BackgroundSwipeTarget $currentCapture
      $argv[4] = [string]$targetInfo.startX
      $argv[5] = [string]$targetInfo.startY
      $argv[6] = [string]$targetInfo.endX
      $argv[7] = [string]$targetInfo.endY
      $argv[8] = [string]$targetInfo.velocity
      $extra.target = $targetInfo
    } elseif ($controlId -eq 'system-camera-permission-allow') {
      $targetInfo = Resolve-SystemCameraPermissionTarget $currentCapture
      $argv[-2] = [string]$targetInfo.x
      $argv[-1] = [string]$targetInfo.y
      $extra.target = $targetInfo
    } elseif ($controlId -eq 'portrait-switch-camera') {
      $targetInfo = Resolve-ToolbarTarget $currentCapture $controlId $false
      $argv[-2] = [string]$targetInfo.x
      $argv[-1] = [string]$targetInfo.y
      $extra.target = $targetInfo
    } elseif ($controlId -eq 'portrait-save') {
      $targetInfo = Resolve-ToolbarTarget $currentCapture $controlId $true
      $argv[-2] = [string]$targetInfo.x
      $argv[-1] = [string]$targetInfo.y
      $extra.target = $targetInfo
    } else {
      $ancestor = if ($controlId -eq 'harness-portrait-route') {
        'pages/RuntimeHarnessPage'
      } else {
        '/hms/PortraitSegmentationActivity'
      }
      $targetInfo = Resolve-ControlTarget $currentCapture $controlId $controlTexts[$controlId] $ancestor
      $argv[-2] = [string]$targetInfo.x
      $argv[-1] = [string]$targetInfo.y
      $extra.target = $targetInfo
    }
    $inputResults += Invoke-Hdc 'command' ($targetPrefix + $argv) $stateName $extra
    if ($stateName -eq 'initial' -and $index -eq 0) {
      Wait-SystemCameraPermission $stateName
      $currentCapture = Capture-State 'permission-dialog' $stateName
    } elseif ($stateName -eq 'initial' -and $index -eq 1) {
      Start-Sleep -Milliseconds 500
      $permissionGranted = Invoke-Hdc 'source.permission.state-after' ($targetPrefix + @(
          'shell', 'atm', 'dump', '-t', '-b', $BundleName
        )) $stateName
      try { $permissionState = $permissionGranted.Stdout | ConvertFrom-Json }
      catch { Fail 'camera permission post-click state is not JSON.' }
      $cameraEntries = @($permissionState.permStateList | Where-Object {
          [string]$_.permissionName -ceq 'ohos.permission.CAMERA'
        })
      $mediaEntries = @($permissionState.permStateList | Where-Object {
          [string]$_.permissionName -ceq 'ohos.permission.READ_IMAGEVIDEO'
        })
      $statesByName = @{}
      foreach ($entry in @($permissionState.permStateList)) {
        $statesByName[[string]$entry.permissionName] = [int]$entry.grantStatus
      }
      if ([string]$permissionState.bundleName -cne $BundleName -or
        $cameraEntries.Count -ne 1 -or $mediaEntries.Count -ne 1 -or
        $statesByName['ohos.permission.CAMERA'] -ne 0 -or
        $statesByName['ohos.permission.READ_IMAGEVIDEO'] -ne -1) {
        Fail 'system dialog did not grant only CAMERA permission.'
      }
      Write-NewTextFile (Join-Path $EvidenceDirectory 'permission-granted.json') `
        $permissionGranted.Stdout
    } elseif ($stateName -eq 'custom-background-cancel' -and $index -eq 0) {
      $currentCapture = Capture-State 'custom-background-swiped' $stateName
    } elseif ($stateName -eq 'custom-background-cancel' -and $index -eq 1) {
      $currentCapture = Capture-PickerState $stateName
    } elseif ($stateName -eq 'reentry' -and $index -eq 0) {
      $currentCapture = Capture-State 'reentry-launcher' $stateName
    }
  }
  [void](Wait-RuntimeEvents $stateName @($expectedRuntimeEventTypes[$stateName]))
  if ($stateName -eq 'save-success') {
    $mediaDelta = Wait-NewMediaAsset $mediaBefore $stateName
    [void](Receive-MediaAsset $mediaDelta.Added $stateName)
  }
  $currentCapture = Capture-State $stateName $stateName
}

$permissionAfter = Invoke-Hdc 'run.permission-after' ($targetPrefix + @(
    'shell', 'atm', 'dump', '-t', '-b', $BundleName
  )) 'save-success' ([ordered]@{ device = $device })
Write-NewTextFile (Join-Path $EvidenceDirectory 'permission-after.json') $permissionAfter.Stdout

Write-Output $OutputPath
