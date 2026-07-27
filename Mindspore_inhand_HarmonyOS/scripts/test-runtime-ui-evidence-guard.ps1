param(
  [ValidateSet('All', 'Positive', 'Core')]
  [string]$Mode = 'All'
)

$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-runtime-ui-evidence.ps1'
$captureRunnerPath = Join-Path $PSScriptRoot 'capture-runtime-ui-run.ps1'
$productionGuardPath = $guardPath
$productionCaptureRunnerPath = $captureRunnerPath
$reviewerPublicKeyPath = Join-Path $PSScriptRoot 'runtime-evidence-reviewer-public.pem'
$templateRoot = Join-Path $PSScriptRoot 'runtime-evidence-templates'
if (-not [IO.File]::Exists($captureRunnerPath)) {
  throw 'Trusted runtime evidence capture runner is missing.'
}
if (-not [IO.File]::Exists($reviewerPublicKeyPath)) {
  throw 'Pinned runtime evidence reviewer public key is missing.'
}
if (-not [IO.Directory]::Exists($templateRoot)) {
  throw 'Trusted runtime evidence producer templates are missing.'
}
$harnessTemplatePath = Join-Path $templateRoot 'RuntimeHarnessPage.ets'
if (-not [IO.File]::Exists($harnessTemplatePath)) {
  throw 'Trusted runtime harness page template is missing.'
}
$harnessTemplate = [IO.File]::ReadAllText($harnessTemplatePath)
function Assert-TrustedHarnessRoute(
  [string]$Source,
  [string]$MethodName,
  [string]$ButtonText,
  [string]$RouteConstant,
  [string]$TitleKey
) {
  foreach ($forbidden in @('/*', '//', [string][char]0x60)) {
    if ($Source.Contains($forbidden)) {
      throw "Trusted runtime harness route '$ButtonText' contains unsupported comment/template syntax."
    }
  }
  $normalized = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
  $structMarker = "@Entry`n@Component`nstruct RuntimeHarnessPage {"
$buildBlock = @"
  build() {
    Column() {
      Button('Open portrait')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openPortrait())
      Button('Open text translation')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openTextTranslation())
      Button('Open style transfer')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openStyleTransfer())
      Button('Open custom model')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openCustomModel())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
"@
  $buildBlock = $buildBlock.Replace("`r`n", "`n").Replace("`r", "`n")
  $structIndex = $normalized.IndexOf($structMarker, [StringComparison]::Ordinal)
  $buildIndex = $normalized.IndexOf($buildBlock, [StringComparison]::Ordinal)
  if ($structIndex -lt 0 -or $buildIndex -le $structIndex -or
    $normalized.IndexOf($structMarker, $structIndex + 1, [StringComparison]::Ordinal) -ge 0 -or
    $normalized.IndexOf($buildBlock, $buildIndex + 1, [StringComparison]::Ordinal) -ge 0 -or
    [regex]::Matches($normalized, '(?m)^\s*@Component\s*$').Count -ne 1 -or
    [regex]::Matches($normalized, '(?m)^\s*struct\s+\w+').Count -ne 1) {
    throw 'Trusted runtime harness must contain one exact RuntimeHarnessPage build.'
  }
$methodBlock = @"
  private ${MethodName}(): void {
    router.pushUrl({
      url: AppRoute.${RouteConstant}.page,
      params: {
        routeName: AppRoute.${RouteConstant}.name,
        titleKey: '${TitleKey}',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }
"@
  $methodBlock = $methodBlock.Replace("`r`n", "`n").Replace("`r", "`n")
  $methodIndex = $normalized.IndexOf($methodBlock, [StringComparison]::Ordinal)
  if ($methodIndex -le $structIndex -or $methodIndex -ge $buildIndex -or
    $normalized.IndexOf($methodBlock, $methodIndex + 1, [StringComparison]::Ordinal) -ge 0) {
    throw "Trusted runtime harness route '$ButtonText' is missing or not exact."
  }
}
Assert-TrustedHarnessRoute $harnessTemplate 'openPortrait' 'Open portrait' `
  'PORTRAIT_SEGMENTATION' 'title_segmentation'
Assert-TrustedHarnessRoute $harnessTemplate 'openTextTranslation' 'Open text translation' `
  'TEXT_TRANSLATION' 'title_texttranslation'
Assert-TrustedHarnessRoute $harnessTemplate 'openStyleTransfer' 'Open style transfer' `
  'STYLE_TRANSFER' 'title_style_transfer'
Assert-TrustedHarnessRoute $harnessTemplate 'openCustomModel' 'Open custom model' `
  'CUSTOM_MODEL' 'title_custom_model'

function Assert-TrustedHarnessDecoyRejected([string]$Name, [string]$Source) {
  try {
    Assert-TrustedHarnessRoute $Source 'openTextTranslation' 'Open text translation' `
      'TEXT_TRANSLATION' 'title_texttranslation'
  } catch {
    return
  }
  throw "Trusted runtime harness route assertion accepted $Name decoy."
}

Assert-TrustedHarnessDecoyRejected 'block-comment' @'
/*
  private openTextTranslation(): void {
    router.pushUrl({
      url: AppRoute.TEXT_TRANSLATION.page,
      params: {
        routeName: AppRoute.TEXT_TRANSLATION.name,
        titleKey: 'title_texttranslation',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }
      Button('Open text translation')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openTextTranslation())
*/
'@
Assert-TrustedHarnessDecoyRejected 'string-literal' @'
Text("private openTextTranslation(): void { router.pushUrl({ url: AppRoute.TEXT_TRANSLATION.page, params: { routeName: AppRoute.TEXT_TRANSLATION.name, titleKey: 'title_texttranslation', runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '', runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? '' } }); } Button('Open text translation').width('80%').constraintSize({ minHeight: 48 }).onClick(() => this.openTextTranslation())")
'@
$translationMethod = @"
  private openTextTranslation(): void {
    router.pushUrl({
      url: AppRoute.TEXT_TRANSLATION.page,
      params: {
        routeName: AppRoute.TEXT_TRANSLATION.name,
        titleKey: 'title_texttranslation',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }
"@
$translationButton = @"
      Button('Open text translation')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openTextTranslation())
"@
$normalizedHarnessTemplate = $harnessTemplate.Replace("`r`n", "`n").Replace("`r", "`n")
$translationMethod = $translationMethod.Replace("`r`n", "`n").Replace("`r", "`n")
$translationButton = $translationButton.Replace("`r`n", "`n").Replace("`r", "`n")
if (($normalizedHarnessTemplate.Split(@($translationMethod), [StringSplitOptions]::None).Count - 1) -ne 1 -or
  ($normalizedHarnessTemplate.Split(@($translationButton), [StringSplitOptions]::None).Count - 1) -ne 1) {
  throw 'Trusted runtime harness unused-component fixture must replace one real route.'
}
$unusedComponentDecoy =
  $normalizedHarnessTemplate.Replace($translationMethod, '').Replace($translationButton, '') + @'

@Component
struct UnusedRouteDecoy {
  private openTextTranslation(): void {}
  build() {
    Button('Open text translation')
      .onClick(() => this.openTextTranslation())
  }
}
'@
Assert-TrustedHarnessDecoyRejected 'unused-component' $unusedComponentDecoy
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

function Join-ByteArrays([object[]]$Arrays) {
  $stream = [IO.MemoryStream]::new()
  try {
    foreach ($array in $Arrays) {
      $bytes = [byte[]]$array
      $stream.Write($bytes, 0, $bytes.Length)
    }
    return $stream.ToArray()
  } finally {
    $stream.Dispose()
  }
}

function New-DerValue([byte]$Tag, [byte[]]$Value) {
  if ($Value.Length -lt 128) {
    $length = [byte[]]@([byte]$Value.Length)
  } else {
    $lengthBytes = [Collections.Generic.List[byte]]::new()
    $remaining = $Value.Length
    while ($remaining -gt 0) {
      $lengthBytes.Insert(0, [byte]($remaining -band 0xff))
      $remaining = $remaining -shr 8
    }
    $length = [byte[]]@([byte](0x80 -bor $lengthBytes.Count)) + $lengthBytes.ToArray()
  }
  return Join-ByteArrays @([byte[]]@($Tag), $length, $Value)
}

function New-DerInteger([byte[]]$Value) {
  if (($Value[0] -band 0x80) -ne 0) { $Value = [byte[]]@(0) + $Value }
  return New-DerValue 0x02 $Value
}

function Export-TestReviewerPublicKey([Security.Cryptography.RSA]$Rsa, [string]$Path) {
  $parameters = $Rsa.ExportParameters($false)
  $rsaPublic = New-DerValue 0x30 (Join-ByteArrays @(
      (New-DerInteger $parameters.Modulus),
      (New-DerInteger $parameters.Exponent)
    ))
  $algorithm = [Convert]::FromBase64String('MA0GCSqGSIb3DQEBAQUA')
  $spki = New-DerValue 0x30 (Join-ByteArrays @(
      $algorithm,
      (New-DerValue 0x03 ([byte[]]@(0) + $rsaPublic))
  ))
  $base64 = [Convert]::ToBase64String($spki, [Base64FormattingOptions]::InsertLineBreaks)
  $normalizedBase64 = $base64.Replace("`r`n", "`n")
  [IO.File]::WriteAllText(
    $Path,
    "-----BEGIN PUBLIC KEY-----`n$normalizedBase64`n-----END PUBLIC KEY-----`n",
    $utf8
  )
}

function Get-TestCanonicalRunRoot([object]$RunReceipt) {
  return ([ordered]@{
      schemaVersion = 1
      domain = 'com.yuhaofeng.mih/runtime-ui-run-root/v1'
      trustDomain = [string]$RunReceipt.trustDomain
      runId = [string]$RunReceipt.runId
      runnerSha256 = [string]$RunReceipt.captureRunner.sha256
      hdcPath = [string]$RunReceipt.hdc.path
      hdcSha256 = [string]$RunReceipt.hdc.sha256
      startedUtc = [string]$RunReceipt.startedUtc
      endedUtc = [string]$RunReceipt.endedUtc
      hapSha256 = [string]$RunReceipt.hapSha256
      buildReceiptSha256 = [string]$RunReceipt.buildReceiptSha256
      candidateDiffSha256 = [string]$RunReceipt.candidateDiffSha256
      candidateIdentitySha256 = [string]$RunReceipt.candidateIdentitySha256
      gitHead = [string]$RunReceipt.gitHead
      routeName = [string]$RunReceipt.routeName
      fontScale = [string]$RunReceipt.fontScale
      density = [string]$RunReceipt.density
      displayDumpSha256 = [string]$RunReceipt.displayDumpSha256
      foregroundAaSha256 = [string]$RunReceipt.foregroundAaSha256
      device = $RunReceipt.device
      steps = @($RunReceipt.steps)
      transcriptSha256 = [string]$RunReceipt.transcriptSha256
      transcriptLength = [int64]$RunReceipt.transcriptLength
      eventCount = [int]$RunReceipt.eventCount
      finalLineSha256 = [string]$RunReceipt.finalLineSha256
      stateReceiptSha256 = @($RunReceipt.stateReceiptSha256)
      stateChainRootSha256 = [string]$RunReceipt.stateChainRootSha256
    } | ConvertTo-Json -Compress -Depth 30)
}

function Invoke-EvidenceGuard([string]$ManifestPath, [switch]$ProductionTrust) {
  if ($ProductionTrust) {
    & $productionGuardPath -ManifestPath $ManifestPath
  } else {
    & $guardPath -ManifestPath $ManifestPath
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
        $variantCode = @($Variant.ToCharArray() | ForEach-Object { [int]$_ } |
            Measure-Object -Sum).Sum
        $marker = [Drawing.Color]::FromArgb(
          255,
          40 + ($variantCode % 180),
          40 + (($variantCode * 3) % 180),
          40 + (($variantCode * 7) % 180)
        )
        $graphics.FillRectangle([Drawing.SolidBrush]::new($marker), 70, 1350, 1180, 180)
        for ($offset = 0; $offset -lt 1180; $offset += 60) {
          $graphics.FillRectangle([Drawing.SolidBrush]::new($secondary), 70 + $offset, 1350, 30, 180)
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

function New-MockHdc([string]$Path) {
  $source = @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

public static class MockHdc {
  static string Q(string value) { return value.Replace("\\", "\\\\").Replace("\"", "\\\""); }
  static void Emit(string run, string state, string type, int index, double offsetSeconds, string fields) {
    Console.WriteLine("MIH_RUNTIME_EVENT {\"runId\":\"" + Q(run) + "\",\"type\":\"" +
      type + "\",\"eventId\":\"preloaded-runtime-" +
      index + "\"" + fields + "}");
  }
  public static int Main(string[] args) {
    Console.OutputEncoding = new System.Text.UTF8Encoding(false);
    Console.InputEncoding = new System.Text.UTF8Encoding(false);
    string run = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_RUN_ID") ?? "";
    string state = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_STATE") ?? "";
    string joined = String.Join(" ", args);
    if (joined == "list targets -v") {
      Console.WriteLine("127.0.0.1:5555\t\tTCP\tConnected\tlocalhost\thdc");
      return 0;
    }
    if (joined.EndsWith("shell aa dump -a")) {
      string capture = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_CAPTURE_NAME") ?? "";
      string evidence = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_DIRECTORY") ?? "";
      string waitMarker = Path.Combine(evidence, "mock-permission-ready.txt");
      string saveWaitMarker = Path.Combine(evidence, "mock-save-dialog-ready.txt");
      if (capture == "permission-wait" && !File.Exists(waitMarker)) {
        File.WriteAllText(waitMarker, "next poll is ready");
        Console.WriteLine("Mission app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND");
      } else if (capture == "permission-dialog" || capture == "permission-wait") {
        Console.WriteLine(
          "  ExtensionRecords:\n" +
          "    uri [/com.huawei.hmos.security.privacycenter/permissionmanager/PermissionGrantAbility3]\n" +
          "      AbilityRecord ID #36   state #FOREGROUND\n" +
          "      main name [PermissionGrantAbility]\n" +
          "      bundle name [com.huawei.hmos.security.privacycenter]\n" +
          "      ability type [UIEXTENSION]\n" +
           "      app state #FOREGROUND\n" +
           "        isKeepAlive: false\n" +
           "    PendingWantRecords:");
      } else if (capture == "save-dialog-wait" && !File.Exists(saveWaitMarker)) {
        File.WriteAllText(saveWaitMarker, "next poll is ready");
        Console.WriteLine("Mission app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND");
      } else if (capture == "save-dialog" || capture == "save-dialog-wait") {
        Console.WriteLine(
          "  ExtensionRecords:\n" +
          "    uri [/com.huawei.hmos.photos/phone_photos/SaveUIExtensionAbility12]\n" +
          "      AbilityRecord ID #53   state #FOREGROUND\n" +
          "      main name [SaveUIExtensionAbility]\n" +
          "      bundle name [com.huawei.hmos.photos]\n" +
          "      ability type [UIEXTENSION]\n" +
          "      app state #FOREGROUND\n" +
          "      root host bundle name [com.yuhaofeng.mih]\n" +
          "      root host ability name [EntryAbility]\n" +
          "    PendingWantRecords:");
      } else {
        Console.WriteLine(capture == "picker-intermediate"
          ? "app name [com.ohos.medialibrary.medialibrarydata] main name [MediaPicker] state #FOREGROUND"
          : "app name [com.yuhaofeng.mih] main name [EntryAbility] state #FOREGROUND");
      }
      return 0;
    }
    if (joined.EndsWith("shell hidumper -s DisplayManagerService -a -a")) {
      Console.WriteLine("width=1320 height=2856 density=3.5");
      return 0;
    }
    if (joined.EndsWith("shell atm dump -t -b com.yuhaofeng.mih")) {
      string evidence = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_DIRECTORY") ?? "";
      int camera = state == "save-success" ||
        File.Exists(Path.Combine(evidence, "mock-camera-granted.txt")) ? 0 : -1;
      Console.WriteLine("{\"bundleName\":\"com.yuhaofeng.mih\",\"permStateList\":[" +
        "{\"permissionName\":\"ohos.permission.CAMERA\",\"grantStatus\":" + camera + "}," +
        "{\"permissionName\":\"ohos.permission.READ_IMAGEVIDEO\",\"grantStatus\":-1}]}");
      return 0;
    }
    if (joined.Contains(" file recv ")) {
      string destination = args[args.Length - 1];
      string capture = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_CAPTURE_NAME") ?? "";
      string templateRoot = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_MOCK_TEMPLATE_DIR") ?? "";
      if (destination.EndsWith("save-success-asset.jpg", StringComparison.OrdinalIgnoreCase)) {
        File.Copy(Path.Combine(templateRoot, "save-success.jpeg"), destination, false);
        Console.WriteLine("FileTransfer finish");
        return 0;
      }
      if (capture == "picker-intermediate" &&
        destination.EndsWith(".json", StringComparison.OrdinalIgnoreCase)) {
        File.WriteAllBytes(destination, new byte[0]);
        Console.WriteLine("FileTransfer finish");
        return 0;
      }
      string templateName = capture == "reentry-launcher" ? "launcher" : capture;
      string extension = destination.EndsWith(".json", StringComparison.OrdinalIgnoreCase)
        ? ".json"
        : (destination.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? ".png" : ".jpeg");
      string source = Path.Combine(templateRoot, templateName + extension);
      File.Copy(source, destination, false);
      Console.WriteLine("FileTransfer finish");
      return 0;
    }
    if (state == "save-success" && joined.Contains(" uitest uiInput click ") &&
      (Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_CAPTURE_NAME") ?? "") ==
        "save-dialog") {
      string evidence = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_DIRECTORY") ?? "";
      File.WriteAllText(Path.Combine(evidence, "mock-media-created.txt"), "created");
      Console.WriteLine("No Error");
      return 0;
    }
    if (state == "initial" && joined.Contains(" uitest uiInput click ") &&
      (Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_CAPTURE_NAME") ?? "") ==
        "permission-dialog") {
      string evidence = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_DIRECTORY") ?? "";
      File.WriteAllText(Path.Combine(evidence, "mock-camera-granted.txt"), "granted");
      Console.WriteLine("No Error");
      return 0;
    }
    if (joined.Contains(" shell mediatool ls -l ")) {
      string evidence = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_DIRECTORY") ?? "";
      string directory = args[args.Length - 1];
      const string mediaRoot = "/storage/media/100/local/files/Photo";
      if (directory == mediaRoot) {
        Console.WriteLine("drwxr-xr-x 0 Camera");
      } else if (directory == mediaRoot + "/Camera" &&
        File.Exists(Path.Combine(evidence, "mock-media-created.txt"))) {
        string templateRoot = Environment.GetEnvironmentVariable("RUNTIME_EVIDENCE_MOCK_TEMPLATE_DIR") ?? "";
        long size = new FileInfo(Path.Combine(templateRoot, "save-success.jpeg")).Length;
        Console.WriteLine("-rw-r--r-- " + size + " task14-saved.jpg");
      }
      return 0;
    }
    if (joined.Contains(" shell mediatool recv ")) {
      Console.WriteLine("No Error");
      return 0;
    }
    if (joined.EndsWith("shell hilog -x -T MIH_RUNTIME_EVIDENCE")) {
      Console.WriteLine("07-27 04:00:00.000 1 1 I MIH_RUNTIME_EVIDENCE: " +
        "MIH_RUNTIME_EVENT {\"runId\":\"historical-run\",\"stateName\":\"historical-state\"," +
        "\"type\":\"service.success\",\"eventId\":\"historical-event\",\"utc\":\"" +
        DateTime.UtcNow.AddMinutes(-5).ToString("o", CultureInfo.InvariantCulture) + "\"}");
      var events = new List<Tuple<string,string,double>>();
      events.Add(Tuple.Create("camera.position.observed", ",\"cameraPosition\":\"back\"", -4.0));
      events.Add(Tuple.Create("camera.restore", ",\"cameraPosition\":\"back\"", -3.0));
      events.Add(Tuple.Create("service.failure", ",\"errorCode\":\"SEGMENTATION_FAILED\",\"preservedResultFingerprint\":\"real-before\"", -2.0));
      events.Add(Tuple.Create("service.success", ",\"resultFingerprint\":\"real-after\"", -1.0));
      for (int i = 0; i < events.Count; i++) Emit(run, "preloaded", events[i].Item1, i, events[i].Item3, events[i].Item2);
      return 0;
    }
    Console.WriteLine("No Error");
    return 0;
  }
}
'@
  Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $Path -OutputType ConsoleApplication
  return $Path
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
                  [ordered]@{ attributes = (Attrs 'Button' '[700,2550][1260,2750]' 'Settings' 'true'); children = @() },
                  [ordered]@{
                    attributes = (Attrs 'List' '[70,1350][1260,1530]' '' 'false' 'true')
                    children = @(
                      [ordered]@{ attributes = (Attrs 'Button' '[70,1350][350,1530]' 'Background 2' 'true'); children = @() },
                      [ordered]@{ attributes = (Attrs 'Button' '[900,1350][1260,1530]' 'Custom background' 'true'); children = @() }
                    )
                  },
                  [ordered]@{
                    attributes = (Attrs 'Row' '[830,1700][1260,1880]')
                    children = @(
                      [ordered]@{ attributes = (Attrs 'Row' '[830,1700][1040,1880]' '' 'true'); children = @() },
                      [ordered]@{ attributes = (Attrs 'SaveButton' '[1050,1700][1260,1880]' '' 'true'); children = @() }
                    )
                  }
                )
              }
            )
          }
        )
      }
    )
  }
  $fixtureControls = $layout.children[0].children[0].children[0].children
  $fixtureControls[2].attributes.id = 'portrait-retry'
  $fixtureControls[4].children[0].attributes.id = 'portrait-preset-2'
  $fixtureControls[4].children[1].attributes.id = 'portrait-custom-background'
  $fixtureControls[5].children[0].attributes.id = 'portrait-switch-camera'
  $fixtureControls[5].children[1].attributes.id = 'portrait-save'
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

function Convert-FixtureToTask14Harness([string]$ManifestPath, [double]$FontScale) {
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  $repositoryRoot = [string]$manifest.repositoryRoot
  $fixtureRoot = Split-Path -Parent $repositoryRoot
  $candidateFile = Join-Path $repositoryRoot 'entry/src/main/ets/pages/Candidate.ets'
  Invoke-Git $repositoryRoot @('restore', '--', 'entry/src/main/ets/pages/Candidate.ets') | Out-Null

  $entryAbilityPath = Join-Path $repositoryRoot 'entry/src/main/ets/entryability/EntryAbility.ets'
  $featurePagePath = Join-Path $repositoryRoot 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entryAbilityPath)) | Out-Null
  [IO.File]::WriteAllText($entryAbilityPath, "baseline entry ability`n", $utf8)
  [IO.File]::WriteAllText(
    $featurePagePath,
    "@Component`nstruct FeatureRuntimePage {`n" +
      "  private statusKey: string = 'ready';`n" +
      "  aboutToAppear(): void {`n" +
      "    const params = router.getParams() as FeatureRuntimeParams;`n  }`n" +
      "  private async runWorkflowAsync(): Promise<void> {`n    try {`n" +
      "      const frameInputReady = await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);`n" +
      "      if (!frameInputReady) { return; }`n" +
      "      if (!this.isRuntimeRequestCurrent(runtimeRequestId)) { return; }`n" +
      "      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());`n" +
      "    } catch (_) {}`n  }`n" +
      "  private applyLiveCameraPreviewResult(result: object): void {`n" +
      "    if (!result.ok) { return; }`n" +
      "    this.pendingPickTextInputVisible = undefined;`n" +
      "    if (shouldAutoRunLiveRuntimeAfterPreview(workflow)) {`n" +
      "      this.startLiveRuntimeLoop(workflow);`n    }`n  }`n" +
      "  private retryLiveSegmentation(): void {`n" +
      "    if (action !== 'restartInference') { return; }`n" +
      "    this.statusKey = 'preparing';`n" +
      "    this.startLiveRuntimeLoop(workflow);`n  }`n" +
      "  private portraitSegmentationAndroidLayout(): void {`n    Column() {}`n  }`n" +
      "  private async applyAiResult(result: object): Promise<void> {`n" +
      "    this.statusKey = 'ready';`n  }`n" +
      "}`n",
    $utf8
  )
  Invoke-Git $repositoryRoot @(
    'add', '--',
    'entry/src/main/ets/entryability/EntryAbility.ets',
    'entry/src/main/ets/pages/FeatureRuntimePage.ets'
  ) | Out-Null
  Invoke-Git $repositoryRoot @('commit', '--quiet', '-m', 'fixture harness baseline') | Out-Null

  $featureSource = [IO.File]::ReadAllText($featurePagePath)
  $featureSource = "import { RuntimeHarnessAdapter } from '../runtime/RuntimeHarnessAdapter';`n" +
    $featureSource
  $featureSource = $featureSource.Replace(
    "  private statusKey: string = 'ready';",
    "  private statusKey: string = 'ready';`n" +
      "  private runtimeHarnessAdapter: RuntimeHarnessAdapter | undefined = undefined;"
  )
  $featureSource = $featureSource.Replace(
    "    const params = router.getParams() as FeatureRuntimeParams;",
    "    const params = router.getParams() as FeatureRuntimeParams;`n" +
      "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter = RuntimeHarnessAdapter.fromParams(params);`n" +
      "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_END"
  )
  $featureSource = $featureSource.Replace(
    "      const frameInputReady = await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);",
    "      // RUNTIME_UI_HARNESS_FRAME_HOOK_BEGIN`n" +
      "      const frameInputReady = this.runtimeHarnessAdapter !== undefined ||`n" +
      "        await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);`n" +
      "      // RUNTIME_UI_HARNESS_FRAME_HOOK_END"
  )
  $featureSource = $featureSource.Replace(
    "      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());",
    "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN`n" +
      "      const result: AiRunResult = this.runtimeHarnessAdapter === undefined ?`n" +
      "        await aiService.run(workflow, this.aiRunInputs()) :`n" +
      "        await this.runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs());`n" +
      "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_END"
  )
  $featureSource = $featureSource.Replace(
    "    this.pendingPickTextInputVisible = undefined;",
    "    this.pendingPickTextInputVisible = undefined;`n" +
      "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition);`n" +
      "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_END"
  )
  $featureSource = $featureSource.Replace(
    "    this.statusKey = 'preparing';",
    "    // RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter?.allowRetry();`n" +
      "    // RUNTIME_UI_HARNESS_RETRY_HOOK_END`n" +
      "    this.statusKey = 'preparing';"
  )
  [IO.File]::WriteAllText($featurePagePath, $featureSource, $utf8)
  $adapterPath = Join-Path $repositoryRoot `
    'entry/src/main/ets/runtime/RuntimeHarnessAdapter.ets'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($adapterPath)) | Out-Null
  Copy-Item -LiteralPath (Join-Path $templateRoot 'RuntimeHarnessAdapter.ets') `
    -Destination $adapterPath
  Invoke-Git $repositoryRoot @(
    'add', '-N', '--',
    'entry/src/main/ets/runtime/RuntimeHarnessAdapter.ets'
  ) | Out-Null
  $entryTemplate = if ($FontScale -eq 3.2) { 'EntryAbility.font32.ets' } else { 'EntryAbility.default.ets' }
  Copy-Item -LiteralPath (Join-Path $templateRoot $entryTemplate) -Destination $entryAbilityPath
  $harnessPagePath = Join-Path $repositoryRoot 'entry/src/main/ets/pages/RuntimeHarnessPage.ets'
  Copy-Item -LiteralPath (Join-Path $templateRoot 'RuntimeHarnessPage.ets') -Destination $harnessPagePath
  $mainPagesPath = Join-Path $repositoryRoot 'entry/src/main/resources/base/profile/main_pages.json'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($mainPagesPath)) | Out-Null
  Copy-Item -LiteralPath (Join-Path $templateRoot 'main_pages.json') -Destination $mainPagesPath
  Invoke-Git $repositoryRoot @('add', '-N', '--', 'entry/src/main/ets/pages/RuntimeHarnessPage.ets') | Out-Null
  Invoke-Git $repositoryRoot @('add', '-N', '--', 'entry/src/main/resources/base/profile/main_pages.json') | Out-Null

  $candidateDiffPath = Join-Path $fixtureRoot 'candidate.diff'
  [IO.File]::WriteAllText(
    $candidateDiffPath,
    (Invoke-Git $repositoryRoot @('diff', '--binary', 'HEAD', '--')),
    $utf8
  )
  $canonicalHap = Join-Path $repositoryRoot 'entry/build/default/outputs/default/entry-default-unsigned.hap'
  Write-Hap $canonicalHap
  $receiptWriterPath = Join-Path $repositoryRoot 'scripts/write-runtime-ui-build-receipt.ps1'
  & $receiptWriterPath -HapPath $canonicalHap | Out-Null
  $frozenHap = Join-Path $fixtureRoot 'task14-harness.hap'
  Copy-Item -LiteralPath $canonicalHap -Destination $frozenHap
  Copy-Item -LiteralPath "$canonicalHap.runtime-ui-build.json" -Destination "$frozenHap.runtime-ui-build.json"

  $layoutPath = [string]$manifest.states[0].layout
  $layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding utf8 | ConvertFrom-Json
  $layout.children[0].children[0].attributes.key = '/hms/PortraitSegmentationActivity'
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
  $baseState = $manifest.states[0]
  $baseState | Add-Member -NotePropertyName captureSource -NotePropertyValue 'harness'
  $launcherLayoutPath = Join-Path $fixtureRoot 'launcher.json'
  $launcherLayout = [ordered]@{
    attributes = (Attrs 'root' '[0,0][1320,2856]')
    children = @(
      [ordered]@{
        attributes = (Attrs 'Button' '[70,310][630,490]' 'Open portrait' 'true')
        children = @()
      }
    )
  }
  $launcherLayout.attributes.key = 'pages/RuntimeHarnessPage'
  $launcherLayout.children[0].attributes.id = 'harness-portrait-route'
  [IO.File]::WriteAllText($launcherLayoutPath, ($launcherLayout | ConvertTo-Json -Depth 20), $utf8)
  $saveFailedZh = -join @(0x4FDD, 0x5B58, 0x5931, 0x8D25 | ForEach-Object { [char]$_ })
  $saveSucceededZh = -join @(0x4FDD, 0x5B58, 0x6210, 0x529F | ForEach-Object { [char]$_ })
  $stateOrder = @(
    'initial', 'preset-selected', 'custom-background-cancel', 'rear-camera', 'reentry',
    'transient-failure', 'retry-success', 'save-success'
  )
  $predecessors = @{
    'initial' = ''
    'preset-selected' = 'initial'
    'custom-background-cancel' = 'preset-selected'
    'rear-camera' = 'custom-background-cancel'
    'reentry' = 'rear-camera'
    'transient-failure' = 'reentry'
    'retry-success' = 'transient-failure'
    'save-success' = 'retry-success'
  }
  $actionTypes = @{
    'initial' = 'open-route'
    'preset-selected' = 'select-preset'
    'custom-background-cancel' = 'cancel-background-picker'
    'rear-camera' = 'switch-camera'
    'reentry' = 'leave-and-reenter'
    'transient-failure' = 'audited-segmentation-failure'
    'retry-success' = 'retry-segmentation'
    'save-success' = 'save-success'
  }
  $states = @()
  $stateLayouts = @{}
  $stateCaptureEvents = @{}
  $stateInputEvents = @{}
  foreach ($name in $stateOrder) {
    $state = $baseState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $state.name = $name
    $state.layout = Join-Path $fixtureRoot "$name.json"
    $state.screenshot = Join-Path $fixtureRoot "$name.jpeg"
    $stateLayout = $layout | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $statusText = switch ($name) {
      'initial' { 'Ready' }
      'preset-selected' { 'Preset selected' }
      'custom-background-cancel' { 'Preset selected after cancel' }
      'rear-camera' { 'Rear camera' }
      'reentry' { 'Rear camera' }
      'transient-failure' { 'Segmentation failed' }
      'retry-success' { 'Segmentation complete' }
      'save-success' { $saveSucceededZh }
    }
    $stateLayout.children[0].children[0].children[0].children[1].attributes.text = $statusText
    $stateLayout.children[0].children[0].children[0].children[1].attributes.originalText = $statusText
    $state.requiredTexts = @($statusText)
    if ($name -notin @('initial')) {
      $stateLayout.children[0].children[0].children[0].children[4].children[0].attributes |
        Add-Member -NotePropertyName selected -NotePropertyValue 'true'
    }
    if ($name -eq 'save-success') {
      $stateLayout.children[0].children[0].children[0].children += [pscustomobject]@{
        attributes = (Attrs 'Text' '[70,2300][630,2450]' $saveSucceededZh)
        children = @()
      }
    }
    $customLabel = $stateLayout.children[0].children[0].children[0].children[4].children[1]
    $customLabel.attributes.bounds = '[900,1350][1260,1530]'
    $customLabel.attributes.origBounds = '[900,1350][1450,1530]'
    [IO.File]::WriteAllText([string]$state.layout, ($stateLayout | ConvertTo-Json -Depth 20), $utf8)
    if ($name -eq 'custom-background-cancel') {
      Copy-Item -LiteralPath (Join-Path $fixtureRoot 'preset-selected.jpeg') `
        -Destination ([string]$state.screenshot)
    } elseif ($name -eq 'reentry') {
      Copy-Item -LiteralPath (Join-Path $fixtureRoot 'rear-camera.jpeg') `
        -Destination ([string]$state.screenshot)
    } elseif ($name -ne 'initial') {
      Write-Jpeg ([string]$state.screenshot) 1320 2856 $name
    }
    $afterScrollLayoutPath = Join-Path $fixtureRoot "$name-after-scroll.json"
    $afterScrollScreenshotPath = Join-Path $fixtureRoot "$name-after-scroll.jpeg"
    $afterScrollLayout = $stateLayout | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $afterScrollLabel =
      $afterScrollLayout.children[0].children[0].children[0].children[4].children[1]
    $afterScrollLabel.attributes.bounds = '[700,1350][1060,1530]'
    $afterScrollLabel.attributes.origBounds = '[700,1350][1060,1530]'
    [IO.File]::WriteAllText(
      $afterScrollLayoutPath,
      ($afterScrollLayout | ConvertTo-Json -Depth 20),
      $utf8
    )
    Write-Jpeg $afterScrollScreenshotPath 1320 2856 "$name-after-scroll"
    Copy-Item -LiteralPath ([string]$state.layout) `
      -Destination (Join-Path $fixtureRoot "$name-scroll-restored.json")
    Copy-Item -LiteralPath ([string]$state.screenshot) `
      -Destination (Join-Path $fixtureRoot "$name-scroll-restored.jpeg")
    $state | Add-Member -NotePropertyName scrollReachableTexts -NotePropertyValue @(
      [ordered]@{
        selector = 'text:Custom background'
        scrollSelector = 'type:List'
        afterScrollLayout = $afterScrollLayoutPath
        afterScrollScreenshot = $afterScrollScreenshotPath
      }
    )
    $stateLayouts[$name] = [string]$state.layout
    $state | Add-Member -NotePropertyName hdcActionReceiptPath -NotePropertyValue (
      Join-Path $fixtureRoot "$name-action-receipt.json"
    )
    if ($name -eq 'custom-background-cancel') {
      $state.preservedBoundsHashFrom = 'preset-selected'
    } elseif ($name -eq 'transient-failure') {
      $state.preservedBoundsHashFrom = 'reentry'
    }
    $states += $state
  }
  foreach ($state in $states) {
    $name = [string]$state.name
    $predecessor = [string]$predecessors[$name]
    $beforeLayoutPath = if ($name -eq 'initial') {
      $launcherLayoutPath
    } else {
      [string]$stateLayouts[$predecessor]
    }
    $afterLayoutPath = [string]$state.layout
    $events = @(switch ($name) {
      'initial' {
        @([pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 350 400'
            kind = 'click'
            x = 350
            y = 400
            targetSelector = 'text:Open portrait'
            targetLayoutPath = $launcherLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $launcherLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          })
      }
      'preset-selected' {
        @([pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 200 1440'
            kind = 'click'
            x = 200
            y = 1440
            targetSelector = 'text:Background 2'
            targetLayoutPath = $beforeLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $beforeLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          })
      }
      'custom-background-cancel' {
        @(
          [pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 550 1440'
            kind = 'click'
            x = 550
            y = 1440
            targetSelector = 'text:Custom background'
            targetLayoutPath = $beforeLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $beforeLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          },
          [pscustomobject][ordered]@{ command = 'hdc shell uitest uiInput keyEvent Back'; kind = 'key'; key = 'Back' }
        )
      }
      'rear-camera' {
        @([pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 1000 1440'
            kind = 'click'
            x = 1000
            y = 1440
            targetSelector = 'text:Switch camera'
            targetLayoutPath = $beforeLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $beforeLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          })
      }
      'reentry' {
        @(
          [pscustomobject][ordered]@{ command = 'hdc shell uitest uiInput keyEvent Back'; kind = 'key'; key = 'Back' },
          [pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 350 400'
            kind = 'click'
            x = 350
            y = 400
            targetSelector = 'text:Open portrait'
            targetLayoutPath = $launcherLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $launcherLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          }
        )
      }
      'transient-failure' {
        @()
      }
      'retry-success' {
        @([pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 350 2190'
            kind = 'click'
            x = 350
            y = 2190
            targetSelector = 'text:Retry'
            targetLayoutPath = $beforeLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $beforeLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          })
      }
      'save-success' {
        @([pscustomobject][ordered]@{
            command = 'hdc shell uitest uiInput click 1155 1790'
            kind = 'click'
            x = 1155
            y = 1790
            targetSelector = 'structural:portrait-toolbar/save-button'
            targetLayoutPath = $beforeLayoutPath
            targetLayoutSha256 = (Get-FileHash -LiteralPath $beforeLayoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
          })
      }
    })
    $stateInputEvents[$name] = @($events)
  }
  $disclosurePath = Join-Path $fixtureRoot 'harness-disclosure.md'
  [IO.File]::WriteAllText($disclosurePath, 'Route/state-only Task 14 harness; no production success claim.', $utf8)
  $manifest.task = 14
  $manifest.candidateDiffPath = $candidateDiffPath
  $manifest.candidateDiffSha256 =
    (Get-FileHash -LiteralPath $candidateDiffPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest.hapPath = $frozenHap
  $manifest.hapSha256 = (Get-FileHash -LiteralPath $frozenHap -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest.buildReceiptPath = "$frozenHap.runtime-ui-build.json"
  $manifest.commitSha = ''
  $manifest.routeName = '/hms/PortraitSegmentationActivity'
  $manifest.fontScale = $FontScale
  $manifest.source = 'harness'
  $manifest | Add-Member -NotePropertyName harnessDisclosure -NotePropertyValue ([ordered]@{
    kind = 'auditableRouteStateHarness'
    productionSuccessClaim = 'none'
    path = $disclosurePath
  })
  $manifest.states = $states

  $runId = [guid]::NewGuid().ToString('N')
  $transcriptPath = Join-Path $fixtureRoot 'capture-transcript.jsonl'
  $pickerLayoutPath = Join-Path $fixtureRoot 'picker-intermediate.json'
  $pickerShotPath = Join-Path $fixtureRoot 'picker-intermediate.jpeg'
  $pickerAaPath = Join-Path $fixtureRoot 'picker-intermediate-aa.txt'
  $permissionDialogPath = Join-Path $fixtureRoot 'permission-dialog.json'
  $saveDialogPath = Join-Path $fixtureRoot 'save-dialog.json'
  [IO.File]::WriteAllText($pickerLayoutPath, '{"attributes":{"type":"Picker","bounds":"[0,0][1320,2856]"},"children":[]}', $utf8)
  [IO.File]::WriteAllText(
    $permissionDialogPath,
    '{"attributes":{"bundleName":"com.huawei.hmos.security.privacycenter",' +
      '"pagePath":"pages/permissionGrantDialog/PermissionGrantDialog","type":"root"},' +
      '"children":[{"attributes":{"bounds":"[689,1599][1208,1739]",' +
      '"clickable":"true","enabled":"true","id":"permission_dialog_allow_button",' +
      '"key":"permission_dialog_allow_button","type":"Button","visible":"true"},' +
      '"children":[]}],"broken":"unterminated}',
    $utf8
  )
  $permissionFixtureParsed = $true
  try { [void]([IO.File]::ReadAllText($permissionDialogPath) | ConvertFrom-Json) }
  catch { $permissionFixtureParsed = $false }
  if ($permissionFixtureParsed) {
    throw 'Permission dialog fixture must remain intentionally invalid JSON.'
  }
  [IO.File]::WriteAllText(
    $saveDialogPath,
    '{"attributes":{"type":"root"},"children":[' +
      '{"attributes":{"type":"ModalPage"},"children":[' +
      '{"attributes":{"type":"UIExtensionComponent"},"children":[' +
      '{"attributes":{"bounds":"[688,1648][1208,1788]",' +
      '"clickable":"true","enabled":"true","id":"advanced_dialog_button_1",' +
      '"key":"advanced_dialog_button_1","type":"Button","visible":"true"},' +
      '"children":[]}]}]}],"broken":"unterminated}',
    $utf8
  )
  Write-Jpeg $pickerShotPath 1320 2856 'picker'
  Write-Jpeg (Join-Path $fixtureRoot 'launcher.jpeg') 1320 2856 'launcher'
  Write-Jpeg (Join-Path $fixtureRoot 'permission-dialog.jpeg') 1320 2856 'permission-dialog'
  Write-Jpeg (Join-Path $fixtureRoot 'save-dialog.jpeg') 1320 2856 'save-dialog'
  [IO.File]::WriteAllText($pickerAaPath, 'com.ohos.photos PickerAbility state #FOREGROUND', $utf8)
  Copy-Item -LiteralPath (Join-Path $fixtureRoot 'preset-selected.json') `
    -Destination (Join-Path $fixtureRoot 'custom-background-swiped.json')
  Copy-Item -LiteralPath (Join-Path $fixtureRoot 'preset-selected.jpeg') `
    -Destination (Join-Path $fixtureRoot 'custom-background-swiped.jpeg')
  Add-Type -AssemblyName System.Drawing
  foreach ($jpegTemplate in @(Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.jpeg')) {
    $pngTemplate = [IO.Path]::ChangeExtension($jpegTemplate.FullName, '.png')
    $templateImage = [Drawing.Image]::FromFile($jpegTemplate.FullName)
    try {
      $templateImage.Save($pngTemplate, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $templateImage.Dispose()
    }
  }
  $env:RUNTIME_EVIDENCE_MOCK_TEMPLATE_DIR = $fixtureRoot
  [IO.File]::Delete((Join-Path $fixtureRoot 'permission-before.json'))
  [IO.File]::Delete((Join-Path $fixtureRoot 'permission-after.json'))
  & $captureRunnerPath -RunId $runId -OutputPath $transcriptPath `
    -EvidenceDirectory $fixtureRoot -HapPath $frozenHap -HdcPath $script:mockHdcPath | Out-Null
  $manifest.permissionBeforePath = Join-Path $fixtureRoot 'permission-before.json'
  $manifest.permissionAfterPath = Join-Path $fixtureRoot 'permission-after.json'
  $runnerHash = (Get-FileHash -LiteralPath $captureRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $rawTranscriptLines = @([IO.File]::ReadAllLines($transcriptPath))
  $transcriptEvents = @($rawTranscriptLines | ForEach-Object { $_ | ConvertFrom-Json })
  $deviceEvent = @($transcriptEvents | Where-Object { $_.type -eq 'run.device' })[0]
  $device = [ordered]@{
    transportId = '127.0.0.1:5555'
    serial = '127.0.0.1:5555'
    fingerprint = "127.0.0.1:5555`tTCP`tConnected`tlocalhost`thdc"
    packageFingerprint = 'com.yuhaofeng.mih:entry'
  }
  $runEvents = @($transcriptEvents | Where-Object {
      [string]$_.type -like 'run.*' -and $_.type -ne 'run.device' -and
      $_.PSObject.Properties.Name -notcontains 'stateName'
    })
  $launcherCapture = @($transcriptEvents | Where-Object {
      $_.type -eq 'capture' -and $_.captureName -eq 'launcher'
    })[0]
  foreach ($state in $states) {
    $capture = @($transcriptEvents | Where-Object {
        $_.type -eq 'capture' -and $_.captureName -eq [string]$state.name
      })[0]
    $state.layout = [string]$capture.layoutPath
    $state.screenshot = [string]$capture.screenshotPath
    $stateLayouts[[string]$state.name] = [string]$capture.layoutPath
    $stateCaptureEvents[[string]$state.name] = $capture
    $afterScrollCapture = @($transcriptEvents | Where-Object {
        $_.type -eq 'capture' -and
        $_.captureName -eq "$([string]$state.name)-after-scroll"
      })[0]
    $state.scrollReachableTexts[0].afterScrollLayout = [string]$afterScrollCapture.layoutPath
    $state.scrollReachableTexts[0].afterScrollScreenshot =
      [string]$afterScrollCapture.screenshotPath
  }
  $stateRawLines = @{}
  $stateRangeStarts = @{}
  $offset = 0
  for ($lineIndex = 0; $lineIndex -lt $rawTranscriptLines.Count; $lineIndex++) {
    $line = $rawTranscriptLines[$lineIndex]
    $event = $transcriptEvents[$lineIndex]
    $lineLength = $utf8.GetByteCount($line + "`n")
    if ($event.PSObject.Properties.Name -contains 'stateName') {
      $eventState = [string]$event.stateName
      if (-not $stateRawLines.ContainsKey($eventState)) {
        $stateRawLines[$eventState] = @()
        $stateRangeStarts[$eventState] = $offset
      }
      $stateRawLines[$eventState] += $line
    }
    $offset += $lineLength
  }
  $previousReceiptHash = ''
  $stateReceiptHashes = @()
  $semanticTypes = @{
    'initial' = @()
    'preset-selected' = @()
    'custom-background-cancel' = @()
    'rear-camera' = @('camera.position.observed')
    'reentry' = @('camera.restore')
    'transient-failure' = @('service.failure')
    'retry-success' = @('service.success')
    'save-success' = @()
  }
  $launcherLayoutPath = [string]$launcherCapture.layoutPath
  $launcherShot = [string]$launcherCapture.screenshotPath
  for ($sequence = 0; $sequence -lt $states.Count; $sequence++) {
    $state = $states[$sequence]
    $name = [string]$state.name
    $segmentEvents = @($transcriptEvents | Where-Object { [string]$_.stateName -ceq $name })
    $commands = @($segmentEvents | Where-Object { [string]$_.type -ceq 'command' })
    $runtimeEvents = @($segmentEvents | Where-Object { [string]$_.type -in @($semanticTypes[$name]) })
    $segmentText = (@($stateRawLines[$name]) -join "`n") + "`n"
    $segmentBytes = $utf8.GetBytes($segmentText)
    $rangeStart = [int]$stateRangeStarts[$name]


    $predecessor = [string]$predecessors[$name]
    $beforeLayout = if ($predecessor -eq '') { $launcherLayoutPath } else {
      [string]$stateLayouts[$predecessor]
    }
    $beforeScreenshot = if ($predecessor -eq '') { $launcherShot } else {
      [string](@($states | Where-Object { $_.name -eq $predecessor })[0].screenshot)
    }
    $beforeCapture = if ($predecessor -eq '') { $launcherCapture } else {
      $stateCaptureEvents[$predecessor]
    }
    $afterCapture = $stateCaptureEvents[$name]
    $receipt = [ordered]@{
      schemaVersion = 1
      runId = $runId
      stateName = $name
      sequence = $sequence
      predecessorState = $predecessor
      previousReceiptSha256 = $previousReceiptHash
      actionType = [string]$actionTypes[$name]
      bindings = [ordered]@{
        hapSha256 = [string]$manifest.hapSha256
        candidateDiffSha256 = [string]$manifest.candidateDiffSha256
        candidateIdentitySha256 = [string](
          (Get-Content -LiteralPath $manifest.buildReceiptPath -Raw | ConvertFrom-Json).candidateIdentitySha256
        )
        gitHead = Invoke-Git $repositoryRoot @('rev-parse', 'HEAD')
        routeName = [string]$manifest.routeName
        fontScale = $FontScale
      }
      before = [ordered]@{
        captureEventId = [string]$beforeCapture.eventId
        layoutPath = $beforeLayout
        layoutSha256 = (Get-FileHash -LiteralPath $beforeLayout -Algorithm SHA256).Hash.ToLowerInvariant()
        screenshotPath = $beforeScreenshot
        screenshotSha256 = (Get-FileHash -LiteralPath $beforeScreenshot -Algorithm SHA256).Hash.ToLowerInvariant()
      }
      after = [ordered]@{
        captureEventId = [string]$afterCapture.eventId
        layoutPath = [string]$state.layout
        layoutSha256 = (Get-FileHash -LiteralPath ([string]$state.layout) -Algorithm SHA256).Hash.ToLowerInvariant()
        screenshotPath = [string]$state.screenshot
        screenshotSha256 =
          (Get-FileHash -LiteralPath ([string]$state.screenshot) -Algorithm SHA256).Hash.ToLowerInvariant()
      }
      transcriptRange = [ordered]@{
        start = $rangeStart
        length = $segmentBytes.Length
        sha256 = Get-BytesSha256 $segmentBytes
      }
      commands = @($commands)
      runtimeEventIds = @($runtimeEvents | ForEach-Object { $_.eventId })
    }
    if ($name -eq 'custom-background-cancel') {
      $pickerCapture = @($segmentEvents | Where-Object { $_.type -eq 'picker.capture' })[0]
      $receipt.intermediate = [ordered]@{
        captureEventId = [string]$pickerCapture.eventId
        layoutAvailable = [bool]$pickerCapture.layoutAvailable
        layoutPath = [string]$pickerCapture.layoutPath
        layoutSha256 = [string]$pickerCapture.layoutSha256
        layoutDumpOutcomePath = [string]$pickerCapture.layoutDumpOutcomePath
        layoutDumpOutcomeSha256 = [string]$pickerCapture.layoutDumpOutcomeSha256
        screenshotPath = [string]$pickerCapture.screenshotPath
        screenshotSha256 = [string]$pickerCapture.screenshotSha256
        foregroundAaPath = [string]$pickerCapture.foregroundAaPath
        foregroundAaSha256 = [string]$pickerCapture.foregroundAaSha256
      }
    }
    [IO.File]::WriteAllText([string]$state.hdcActionReceiptPath, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    $receiptHash = (Get-FileHash -LiteralPath ([string]$state.hdcActionReceiptPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    $state | Add-Member -NotePropertyName hdcActionReceiptSha256 -NotePropertyValue $receiptHash
    $stateReceiptHashes += $receiptHash
    $previousReceiptHash = $receiptHash
  }
  $buildReceiptHash =
    (Get-FileHash -LiteralPath ([string]$manifest.buildReceiptPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  $runReceipt = [ordered]@{
    schemaVersion = 1
    trustDomain = 'production'
    runId = $runId
    captureRunner = [ordered]@{ path = $captureRunnerPath; version = 1; sha256 = $runnerHash }
    hdc = [ordered]@{
      path = [IO.Path]::GetFullPath($script:mockHdcPath)
      sha256 = (Get-FileHash -LiteralPath $script:mockHdcPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    startedUtc = (@($transcriptEvents | ForEach-Object { [datetime]$_.utc }) |
      Sort-Object | Select-Object -First 1).ToUniversalTime().ToString('o')
    endedUtc = (@($transcriptEvents | ForEach-Object {
          if ($_.PSObject.Properties.Name -contains 'endedUtc') { [datetime]$_.endedUtc } else { [datetime]$_.utc }
        }) | Sort-Object | Select-Object -Last 1).ToUniversalTime().ToString('o')
    hapSha256 = [string]$manifest.hapSha256
    buildReceiptSha256 = $buildReceiptHash
    candidateDiffSha256 = [string]$manifest.candidateDiffSha256
    candidateIdentitySha256 = [string](
      (Get-Content -LiteralPath $manifest.buildReceiptPath -Raw | ConvertFrom-Json).candidateIdentitySha256
    )
    gitHead = Invoke-Git $repositoryRoot @('rev-parse', 'HEAD')
    routeName = [string]$manifest.routeName
    fontScale = $FontScale
    density = [double]$manifest.density
    displayDumpSha256 =
      (Get-FileHash -LiteralPath ([string]$manifest.displayDumpPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    foregroundAaSha256 =
      (Get-FileHash -LiteralPath ([string]$manifest.aaDumpPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    device = $device
    transcriptPath = $transcriptPath
    transcriptSha256 =
      (Get-FileHash -LiteralPath $transcriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    transcriptLength = [IO.FileInfo]::new($transcriptPath).Length
    eventCount = $transcriptEvents.Count
    finalLineSha256 = Get-BytesSha256 $utf8.GetBytes($rawTranscriptLines[-1] + "`n")
    steps = @($runEvents | ForEach-Object {
        [ordered]@{
          eventId = $_.eventId
          eventSha256 = Get-TextSha256 ($_ | ConvertTo-Json -Compress -Depth 20)
          exitCode = $_.exitCode
        }
      })
    stateReceiptSha256 = $stateReceiptHashes
    stateChainRootSha256 = $stateReceiptHashes[-1]
  }
  $runReceiptPath = Join-Path $fixtureRoot 'run-receipt.json'
  [IO.File]::WriteAllText($runReceiptPath, ($runReceipt | ConvertTo-Json -Depth 30), $utf8)
  $rootPath = Join-Path $fixtureRoot 'run-root.cjson'
  $rootText = Get-TestCanonicalRunRoot $runReceipt
  [IO.File]::WriteAllText($rootPath, $rootText, $utf8)
  $rootBytes = $utf8.GetBytes($rootText)
  $prefix = $utf8.GetBytes("runtime-ui-run-root-v1`0")
  $signedBytes = Join-ByteArrays @($prefix, $rootBytes)
  $signature = $script:testReviewerRsa.SignData(
    $signedBytes,
    [Security.Cryptography.HashAlgorithmName]::SHA256,
    [Security.Cryptography.RSASignaturePadding]::Pss
  )
  $testPem = ([IO.File]::ReadAllText($script:testReviewerPublicKeyPath) -replace
    '-----[^-]+-----', '' -replace '\s', '')
  $signatureEnvelope = [ordered]@{
    schemaVersion = 1
    algorithm = 'RSA-PSS-SHA256-MGF1-SHA256-SALT32'
    keyFingerprint = Get-BytesSha256 ([Convert]::FromBase64String($testPem))
    rootSha256 = Get-BytesSha256 $rootBytes
    signatureBase64 = [Convert]::ToBase64String($signature)
  }
  $signaturePath = Join-Path $fixtureRoot 'run-root-signature.json'
  [IO.File]::WriteAllText($signaturePath, ($signatureEnvelope | ConvertTo-Json -Compress), $utf8)
  $manifest | Add-Member -NotePropertyName runReceiptPath -NotePropertyValue $runReceiptPath
  $manifest | Add-Member -NotePropertyName runReceiptSha256 -NotePropertyValue (
    (Get-FileHash -LiteralPath $runReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  )
  $manifest | Add-Member -NotePropertyName runRootPath -NotePropertyValue $rootPath
  $manifest | Add-Member -NotePropertyName runRootSha256 -NotePropertyValue (
    (Get-FileHash -LiteralPath $rootPath -Algorithm SHA256).Hash.ToLowerInvariant()
  )
  $manifest | Add-Member -NotePropertyName runRootSignaturePath -NotePropertyValue $signaturePath
  $manifest | Add-Member -NotePropertyName runRootSignatureSha256 -NotePropertyValue (
    (Get-FileHash -LiteralPath $signaturePath -Algorithm SHA256).Hash.ToLowerInvariant()
  )
  [IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  return $ManifestPath
}

function Assert-Task14HarnessRejected(
  [string]$Name,
  [scriptblock]$Mutation,
  [string]$ExpectedFailure = ''
) {
  Write-Output "[Task14 mutation] $Name"
  $root = Join-Path $tempRoot $Name
  $manifestPath = Convert-FixtureToTask14Harness (New-Fixture $root) 1.0
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  & $Mutation $manifest $root
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  $rejected = $false
  $failure = ''
  try { Invoke-EvidenceGuard $manifestPath | Out-Null } catch {
    $rejected = $true
    $failure = $_.Exception.Message
  }
  if (-not $rejected) { throw "Runtime evidence guard accepted Task 14 harness mutation: $Name" }
  if (-not [string]::IsNullOrEmpty($ExpectedFailure) -and
    $failure -notlike "*$ExpectedFailure*") {
    throw "Task 14 mutation '$Name' failed for the wrong reason: $failure"
  }
}

function Sign-Task14RunRoot([object]$Manifest) {
  $runReceiptPath = [string]$Manifest.runReceiptPath
  $runReceipt = Get-Content -LiteralPath $runReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json
  $rootText = Get-TestCanonicalRunRoot $runReceipt
  $rootPath = [string]$Manifest.runRootPath
  [IO.File]::WriteAllText($rootPath, $rootText, $utf8)
  $rootBytes = $utf8.GetBytes($rootText)
  $signedBytes = Join-ByteArrays @(
    $utf8.GetBytes("runtime-ui-run-root-v1`0"),
    $rootBytes
  )
  $signature = $script:testReviewerRsa.SignData(
    $signedBytes,
    [Security.Cryptography.HashAlgorithmName]::SHA256,
    [Security.Cryptography.RSASignaturePadding]::Pss
  )
  $testPem = ([IO.File]::ReadAllText($script:testReviewerPublicKeyPath) -replace
    '-----[^-]+-----', '' -replace '\s', '')
  $signatureEnvelope = [ordered]@{
    schemaVersion = 1
    algorithm = 'RSA-PSS-SHA256-MGF1-SHA256-SALT32'
    keyFingerprint = Get-BytesSha256 ([Convert]::FromBase64String($testPem))
    rootSha256 = Get-BytesSha256 $rootBytes
    signatureBase64 = [Convert]::ToBase64String($signature)
  }
  [IO.File]::WriteAllText(
    [string]$Manifest.runRootSignaturePath,
    ($signatureEnvelope | ConvertTo-Json -Compress),
    $utf8
  )
  $Manifest.runReceiptSha256 =
    (Get-FileHash -LiteralPath $runReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $Manifest.runRootSha256 =
    (Get-FileHash -LiteralPath $rootPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $Manifest.runRootSignatureSha256 =
    (Get-FileHash -LiteralPath ([string]$Manifest.runRootSignaturePath) -Algorithm SHA256).
      Hash.ToLowerInvariant()
}

function Sync-Task14RunRoot([object]$Manifest, [bool]$Rechain = $true) {
  $previous = ''
  $hashes = @()
  foreach ($state in @($Manifest.states)) {
    $receiptPath = [string]$state.hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($Rechain) { $receipt.previousReceiptSha256 = $previous }
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    $hash = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $state.hdcActionReceiptSha256 = $hash
    $hashes += $hash
    $previous = $hash
  }
  $run = Get-Content -LiteralPath ([string]$Manifest.runReceiptPath) -Raw -Encoding utf8 |
    ConvertFrom-Json
  $run.stateReceiptSha256 = $hashes
  $run.stateChainRootSha256 = $hashes[-1]
  $run.transcriptSha256 =
    (Get-FileHash -LiteralPath ([string]$run.transcriptPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText([string]$Manifest.runReceiptPath, ($run | ConvertTo-Json -Depth 30), $utf8)
  Sign-Task14RunRoot $Manifest
}

function Rewrite-Task14Transcript(
  [object]$Manifest,
  [scriptblock]$Mutation,
  [bool]$SyncCommands = $false,
  [bool]$SyncNonces = $false
) {
  $run = Get-Content -LiteralPath ([string]$Manifest.runReceiptPath) -Raw -Encoding utf8 |
    ConvertFrom-Json
  $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) | ForEach-Object {
      $_ | ConvertFrom-Json
    })
  & $Mutation $events
  $runEvents = @($events | Where-Object { $_.PSObject.Properties.Name -notcontains 'stateName' })
  $orderedGroups = [Collections.Generic.List[object]]::new()
  $orderedGroups.Add([pscustomobject]@{ Name = ''; Events = $runEvents })
  foreach ($state in @($Manifest.states)) {
    $orderedGroups.Add([pscustomobject]@{
        Name = [string]$state.name
        Events = @($events | Where-Object { [string]$_.stateName -ceq [string]$state.name })
      })
  }
  $text = ''
  $previousLineSha256 = ('0' * 64)
  $sequence = 0
  $segments = @{}
  foreach ($group in $orderedGroups) {
    $segmentStart = $utf8.GetByteCount($text)
    $segment = ''
    foreach ($event in @($group.Events)) {
      $event.sequence = $sequence
      if ($SyncNonces) {
        $nonce = [string]$event.nonce
        $separator = $nonce.LastIndexOf(':')
        if ($separator -lt 0) { throw 'Task 14 fixture event nonce is invalid.' }
        $event.nonce =
          "$([string]$event.runId):$($sequence.ToString('D6')):$($nonce.Substring($separator + 1))"
      }
      $event.previousLineSha256 = $previousLineSha256
      $line = ($event | ConvertTo-Json -Compress -Depth 20) + "`n"
      $segment += $line
      $previousLineSha256 = Get-BytesSha256 ($utf8.GetBytes($line))
      $sequence++
    }
    $text += $segment
    $segments[[string]$group.Name] = [pscustomobject]@{
      Start = $segmentStart
      Text = $segment
      Events = @($group.Events)
    }
  }
  foreach ($state in @($Manifest.states)) {
    $group = $segments[[string]$state.name]
    $stateEvents = @($group.Events)
    $segment = [string]$group.Text
    $receipt = Get-Content -LiteralPath ([string]$state.hdcActionReceiptPath) -Raw -Encoding utf8 |
      ConvertFrom-Json
    $receipt.transcriptRange.start = [int64]$group.Start
    $receipt.transcriptRange.length = $utf8.GetByteCount($segment)
    $receipt.transcriptRange.sha256 = Get-BytesSha256 ($utf8.GetBytes($segment))
    if ($SyncCommands) {
      $receipt.commands = @($stateEvents | Where-Object { [string]$_.type -eq 'command' })
    }
    [IO.File]::WriteAllText(
      [string]$state.hdcActionReceiptPath,
      ($receipt | ConvertTo-Json -Depth 30),
      $utf8
    )
  }
  [IO.File]::WriteAllText([string]$run.transcriptPath, $text, $utf8)
  $run.transcriptSha256 =
    (Get-FileHash -LiteralPath ([string]$run.transcriptPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  $run.transcriptLength = [IO.FileInfo]::new([string]$run.transcriptPath).Length
  $run.eventCount = $sequence
  $run.finalLineSha256 = $previousLineSha256
  [IO.File]::WriteAllText(
    [string]$Manifest.runReceiptPath,
    ($run | ConvertTo-Json -Depth 30),
    $utf8
  )
  Sync-Task14RunRoot $Manifest
}

function Sync-Task14CandidateBinding([object]$Manifest) {
  $repositoryRoot = [string]$Manifest.repositoryRoot
  [IO.File]::WriteAllText(
    [string]$Manifest.candidateDiffPath,
    (Invoke-Git $repositoryRoot @('diff', '--binary', 'HEAD', '--')),
    $utf8
  )
  $Manifest.candidateDiffSha256 =
    (Get-FileHash -LiteralPath ([string]$Manifest.candidateDiffPath) -Algorithm SHA256).
      Hash.ToLowerInvariant()
  $canonicalHap = Join-Path $repositoryRoot 'entry/build/default/outputs/default/entry-default-unsigned.hap'
  & (Join-Path $repositoryRoot 'scripts/write-runtime-ui-build-receipt.ps1') `
    -HapPath $canonicalHap | Out-Null
  Copy-Item -LiteralPath "$canonicalHap.runtime-ui-build.json" `
    -Destination ([string]$Manifest.buildReceiptPath) -Force
  $build = Get-Content -LiteralPath ([string]$Manifest.buildReceiptPath) -Raw -Encoding utf8 |
    ConvertFrom-Json
  foreach ($state in @($Manifest.states)) {
    $receiptPath = [string]$state.hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.bindings.candidateDiffSha256 = [string]$Manifest.candidateDiffSha256
    $receipt.bindings.candidateIdentitySha256 = [string]$build.candidateIdentitySha256
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 30), $utf8)
  }
  $run = Get-Content -LiteralPath ([string]$Manifest.runReceiptPath) -Raw -Encoding utf8 |
    ConvertFrom-Json
  $run.candidateDiffSha256 = [string]$Manifest.candidateDiffSha256
  $run.candidateIdentitySha256 = [string]$build.candidateIdentitySha256
  $run.buildReceiptSha256 =
    (Get-FileHash -LiteralPath ([string]$Manifest.buildReceiptPath) -Algorithm SHA256).
      Hash.ToLowerInvariant()
  [IO.File]::WriteAllText(
    [string]$Manifest.runReceiptPath,
    ($run | ConvertTo-Json -Depth 30),
    $utf8
  )
  Sync-Task14RunRoot $Manifest
}

function Invoke-Task14CoreMutations {
  Assert-Task14HarnessRejected 'task14-permission-capture-removed' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object {
          [string]$_.captureName -eq 'permission-dialog' -and [string]$_.type -eq 'capture'
        })[0].type = 'capture.removed'
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-source-argv' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $event = @($events | Where-Object {
          [string]$_.type -eq 'source.permission.state-after'
        })[0]
      $event.argv[-1] = 'com.example.decoy'
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-source-before-route' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $capture = @($events | Where-Object {
          [string]$_.captureName -eq 'permission-dialog'
        })[0]
      $sourceId = [string]$capture.sourceCommandEventIds[0]
      $routeIndex = -1
      $sourceIndex = -1
      for ($index = 0; $index -lt $events.Count; $index++) {
        if ([string]$events[$index].controlId -eq 'harness-portrait-route' -and
          [string]$events[$index].stateName -eq 'initial') { $routeIndex = $index }
        if ([string]$events[$index].eventId -eq $sourceId) { $sourceIndex = $index }
      }
      $temporary = $events[$routeIndex]
      $events[$routeIndex] = $events[$sourceIndex]
      $events[$sourceIndex] = $temporary
    } $true $true
  } 'task 14 camera permission UI grant evidence is missing, reordered, or unbound.'
  Assert-Task14HarnessRejected 'task14-initial-source-before-permission-state' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $capture = @($events | Where-Object { [string]$_.captureName -eq 'initial' })[0]
      $sourceId = [string]$capture.sourceCommandEventIds[0]
      $permissionIndex = -1
      $sourceIndex = -1
      for ($index = 0; $index -lt $events.Count; $index++) {
        if ([string]$events[$index].type -eq 'source.permission.state-after') {
          $permissionIndex = $index
        }
        if ([string]$events[$index].eventId -eq $sourceId) { $sourceIndex = $index }
      }
      $temporary = $events[$permissionIndex]
      $events[$permissionIndex] = $events[$sourceIndex]
      $events[$sourceIndex] = $temporary
    } $true $true
  } 'task 14 camera permission UI grant evidence is missing, reordered, or unbound.'
  Assert-Task14HarnessRejected 'task14-permission-poll-claimed-ready-too-early' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $waits = @($events | Where-Object {
          [string]$_.type -eq 'source.permission.wait-aa'
        })
      $waits[0].stdout = [string]$waits[-1].stdout
      $waits[0].stdoutSha256 = Get-BytesSha256 $utf8.GetBytes([string]$waits[0].stdout)
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-poll-unbounded-timeout' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object {
          [string]$_.type -eq 'source.permission.wait-aa'
        })[0].timeoutMilliseconds = 300000
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-duplicate-allow-target' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw | ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $capture = @($events | Where-Object { [string]$_.captureName -eq 'permission-dialog' })[0]
    $path = [string]$capture.layoutPath
    [IO.File]::AppendAllText(
      $path,
      ',"attributes":{"bounds":"[100,100][500,300]","clickable":"true",' +
        '"enabled":"true","id":"permission_dialog_allow_button",' +
        '"key":"permission_dialog_allow_button","type":"Button","visible":"true"},"children":[]',
      $utf8
    )
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($rewritten)
      @($rewritten | Where-Object { [string]$_.captureName -eq 'permission-dialog' })[0].
        layoutSha256 = $hash
      @($rewritten | Where-Object {
          [string]$_.stateName -eq 'initial' -and
          [string]$_.controlId -eq 'system-camera-permission-allow'
        })[0].target.layoutSha256 = $hash
    } $true
  }
  Assert-Task14HarnessRejected 'task14-permission-forged-foreground' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw | ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $capture = @($events | Where-Object { [string]$_.captureName -eq 'permission-dialog' })[0]
    $path = [string]$capture.foregroundAaPath
    $text = @"
  ExtensionRecords:
    uri [/com.huawei.hmos.security.privacycenter/permissionmanager/PermissionGrantAbility3]
      AbilityRecord ID #36   state #BACKGROUND
      main name [PermissionGrantAbility]
      bundle name [com.huawei.hmos.security.privacycenter]
      ability type [UIEXTENSION]
      app state #BACKGROUND
    uri [/com.yuhaofeng.mih/entry/EntryAbility]
      AbilityRecord ID #35   state #FOREGROUND
      main name [EntryAbility]
      bundle name [com.yuhaofeng.mih]
      app state #FOREGROUND
    PendingWantRecords:
"@
    [IO.File]::WriteAllText($path, $text, $utf8)
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($rewritten)
      $permissionCapture = @($rewritten | Where-Object {
          [string]$_.captureName -eq 'permission-dialog'
        })[0]
      $permissionCapture.foregroundAaSha256 = $hash
      $aa = @($rewritten | Where-Object {
          [string]$_.eventId -eq [string]$permissionCapture.sourceCommandEventIds[4]
        })[0]
      $aa.stdout = $text
      $aa.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes($text)
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-ability-type-downgrade' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw | ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $capture = @($events | Where-Object { [string]$_.captureName -eq 'permission-dialog' })[0]
    $path = [string]$capture.foregroundAaPath
    $text = [IO.File]::ReadAllText($path).Replace(
      'ability type [UIEXTENSION]',
      'ability type [SERVICE]'
    )
    [IO.File]::WriteAllText($path, $text, $utf8)
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($rewritten)
      $permissionCapture = @($rewritten | Where-Object {
          [string]$_.captureName -eq 'permission-dialog'
        })[0]
      $permissionCapture.foregroundAaSha256 = $hash
      $aa = @($rewritten | Where-Object {
          [string]$_.eventId -eq [string]$permissionCapture.sourceCommandEventIds[4]
        })[0]
      $aa.stdout = $text
      $aa.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes($text)
    }
  }
  Assert-Task14HarnessRejected 'task14-permission-click-off-center' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $command = @($events | Where-Object {
          [string]$_.stateName -eq 'initial' -and
          [string]$_.controlId -eq 'system-camera-permission-allow'
        })[0]
      $command.target.x = [int]$command.target.x + 10
      $command.argv[-2] = [string]$command.target.x
    } $true
  }
  Assert-Task14HarnessRejected 'task14-permission-state-not-granted' {
    param($manifest, $root)
    $path = Join-Path $root 'permission-granted.json'
    Write-PermissionProof $path -1 -1
    $text = [IO.File]::ReadAllText($path)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $event = @($events | Where-Object {
          [string]$_.type -eq 'source.permission.state-after'
        })[0]
      $event.stdout = $text
      $event.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes($text)
    }
  }
  Assert-Task14HarnessRejected 'task14-save-dialog-capture-removed' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object {
          [string]$_.captureName -eq 'save-dialog' -and [string]$_.type -eq 'capture'
        })[0].type = 'capture.removed'
    }
  }
  Assert-Task14HarnessRejected 'task14-save-dialog-poll-argv' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object {
          [string]$_.type -eq 'source.save-dialog.wait-aa'
        })[0].argv[-1] = '--forged'
    }
  }
  Assert-Task14HarnessRejected 'task14-save-dialog-foreground-downgrade' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw | ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $capture = @($events | Where-Object { [string]$_.captureName -eq 'save-dialog' })[0]
    $path = [string]$capture.foregroundAaPath
    $text = [IO.File]::ReadAllText($path).Replace(
      'ability type [UIEXTENSION]',
      'ability type [SERVICE]'
    )
    [IO.File]::WriteAllText($path, $text, $utf8)
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($rewritten)
      $saveCapture = @($rewritten | Where-Object {
          [string]$_.captureName -eq 'save-dialog'
        })[0]
      $saveCapture.foregroundAaSha256 = $hash
      $aa = @($rewritten | Where-Object {
          [string]$_.eventId -eq [string]$saveCapture.sourceCommandEventIds[4]
        })[0]
      $aa.stdout = $text
      $aa.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes($text)
    }
  }
  Assert-Task14HarnessRejected 'task14-save-dialog-click-off-center' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $command = @($events | Where-Object {
          [string]$_.stateName -eq 'save-success' -and
          [string]$_.controlId -eq 'system-photo-save-allow'
        })[0]
      $command.target.x = [int]$command.target.x + 10
      $command.argv[-2] = [string]$command.target.x
    } $true
  }
  Assert-Task14HarnessRejected 'task14-after-scroll-capture-removed' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object {
          [string]$_.captureName -eq 'initial-after-scroll' -and
          [string]$_.type -eq 'capture'
        })[0].type = 'capture.removed'
    }
  }
  Assert-Task14HarnessRejected 'task14-scroll-restore-wrong-direction' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $command = @($events | Where-Object {
          [string]$_.stateName -eq 'initial' -and
          [string]$_.controlId -eq 'portrait-background-strip-scroll-restore'
        })[0]
      $start = [string]$command.target.startX
      $command.target.startX = [int]$command.target.endX
      $command.target.endX = [int]$start
      $command.argv[6] = [string]$command.target.startX
      $command.argv[8] = [string]$command.target.endX
    } $true
  }
  Assert-Task14HarnessRejected 'task14-scroll-restore-content-not-restored' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw | ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $after = @($events | Where-Object {
        [string]$_.captureName -eq 'initial-after-scroll'
      })[0]
    $restored = @($events | Where-Object {
        [string]$_.captureName -eq 'initial-scroll-restored'
      })[0]
    foreach ($field in @('layoutPath', 'rawScreenshotPath', 'screenshotPath')) {
      Copy-Item -LiteralPath ([string]$after.$field) -Destination ([string]$restored.$field) -Force
    }
    $restoredLayoutHash =
      (Get-FileHash -LiteralPath ([string]$restored.layoutPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    $restoredEventId = [string]$restored.eventId
    Rewrite-Task14Transcript $manifest {
      param($rewritten)
      $capture = @($rewritten | Where-Object {
          [string]$_.captureName -eq 'initial-scroll-restored'
        })[0]
      $capture.layoutSha256 = $restoredLayoutHash
      $capture.rawScreenshotSha256 =
        (Get-FileHash -LiteralPath ([string]$capture.rawScreenshotPath) -Algorithm SHA256).Hash.ToLowerInvariant()
      $capture.screenshotSha256 =
        (Get-FileHash -LiteralPath ([string]$capture.screenshotPath) -Algorithm SHA256).Hash.ToLowerInvariant()
      $nextCommand = @($rewritten | Where-Object {
          [string]$_.type -eq 'command' -and [string]$_.stateName -eq 'preset-selected' -and
          [string]$_.target.captureEventId -eq $restoredEventId
        })[0]
      $nextCommand.target.layoutSha256 = $restoredLayoutHash
    } $true
  } 'restored List differs from its signed base'
  Assert-Task14HarnessRejected 'task14-prewritten-layout-not-from-runner' {
    param($manifest, $root)
    $state = $manifest.states[1]
    $prewrittenPath = Join-Path (Split-Path -Parent ([string]$state.layout)) `
      'prewritten-preset-layout.json'
    Copy-Item -LiteralPath ([string]$state.layout) -Destination $prewrittenPath
    $state.layout = $prewrittenPath
    $receiptPath = [string]$state.hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.after.layoutPath = $prewrittenPath
    $receipt.after.layoutSha256 =
      (Get-FileHash -LiteralPath $prewrittenPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $manifest
  }
  Assert-Task14HarnessRejected 'task14-keyword-free-button-in-protected-builder' {
    param($manifest, $root)
    $featurePath = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($featurePath)
    $source = $source.Replace('    Column() {}', "    Column() { Button('decoy') }")
    [IO.File]::WriteAllText($featurePath, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-keyword-free-state-write-in-apply-result' {
    param($manifest, $root)
    $featurePath = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($featurePath)
    $source = $source.Replace(
      "    this.statusKey = 'ready';",
      "    this.statusKey = 'ready';`n    this.statusKey = 'idle';"
    )
    [IO.File]::WriteAllText($featurePath, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-adapter-extra-fake-result' {
    param($manifest, $root)
    $adapterPath = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/runtime/RuntimeHarnessAdapter.ets'
    $source = [IO.File]::ReadAllText($adapterPath).Replace(
      '    const result = this.syntheticSegmentationResult(inputs);',
      '    const result = fakeAiRunResult;'
    )
    [IO.File]::WriteAllText($adapterPath, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-adapter-retry-recovery-removed' {
    param($manifest, $root)
    $adapterPath = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/runtime/RuntimeHarnessAdapter.ets'
    $source = [IO.File]::ReadAllText($adapterPath).Replace(
      '      this.recovered = true;',
      '      this.recovered = false;'
    )
    [IO.File]::WriteAllText($adapterPath, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-frame-bypass-leaks-to-production' {
    param($manifest, $root)
    $featurePath = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($featurePath).Replace(
      '      const frameInputReady = this.runtimeHarnessAdapter !== undefined ||',
      '      const frameInputReady = true ||'
    )
    [IO.File]::WriteAllText($featurePath, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-harness-page-decoy-ui' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/RuntimeHarnessPage.ets'
    [IO.File]::AppendAllText($path, "`n@Component struct DecoyPortrait { build() { Text('fake') } }`n", $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-entry-ability-extra-startup-behavior' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/entryability/EntryAbility.ets'
    $source = [IO.File]::ReadAllText($path).Replace(
      "    windowStage.loadContent('pages/RuntimeHarnessPage')",
      "    globalThis.unreviewedStartup = true;`n    windowStage.loadContent('pages/RuntimeHarnessPage')"
    )
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-retry-hook-moved-to-camera-method' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $retryBlock = "    // RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter?.allowRetry();`n" +
      "    // RUNTIME_UI_HARNESS_RETRY_HOOK_END`n"
    $source = $source.Replace($retryBlock, '')
    $source = $source.Replace(
      '    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN',
      $retryBlock + '    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN'
    )
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-route-hook-before-params-within-method' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $paramsLine = '    const params = router.getParams() as FeatureRuntimeParams;'
    $hook = "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter = RuntimeHarnessAdapter.fromParams(params);`n" +
      "    // RUNTIME_UI_HARNESS_ROUTE_HOOK_END"
    $source = $source.Replace("$paramsLine`n$hook", "$hook`n$paramsLine")
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-service-hook-before-try-within-method' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $hook = "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN`n" +
      "      const result: AiRunResult = this.runtimeHarnessAdapter === undefined ?`n" +
      "        await aiService.run(workflow, this.aiRunInputs()) :`n" +
      "        await this.runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs());`n" +
      "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_END`n"
    $source = $source.Replace($hook, '')
    $source = $source.Replace(
      "  private async runWorkflowAsync(): Promise<void> {`n    try {",
      "  private async runWorkflowAsync(): Promise<void> {`n$hook    try {"
    )
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-service-hook-before-stale-request-guard' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $hook = "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_BEGIN`n" +
      "      const result: AiRunResult = this.runtimeHarnessAdapter === undefined ?`n" +
      "        await aiService.run(workflow, this.aiRunInputs()) :`n" +
      "        await this.runtimeHarnessAdapter.run(aiService, workflow, this.aiRunInputs());`n" +
      "      // RUNTIME_UI_HARNESS_SERVICE_HOOK_END"
    $source = $source.Replace("$hook`n", '')
    $guard = '      if (!this.isRuntimeRequestCurrent(runtimeRequestId)) { return; }'
    $source = $source.Replace($guard, "$hook`n$guard")
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-camera-hook-inside-failure-guard-within-method' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $postGuardLine = '    this.pendingPickTextInputVisible = undefined;'
    $hook = "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter?.observeCamera(this.liveCameraPosition);`n" +
      "    // RUNTIME_UI_HARNESS_CAMERA_HOOK_END"
    $source = $source.Replace("$postGuardLine`n$hook", "$hook`n$postGuardLine")
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-retry-hook-after-trigger-within-method' {
    param($manifest, $root)
    $path = Join-Path ([string]$manifest.repositoryRoot) `
      'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    $source = [IO.File]::ReadAllText($path)
    $hook = "    // RUNTIME_UI_HARNESS_RETRY_HOOK_BEGIN`n" +
      "    this.runtimeHarnessAdapter?.allowRetry();`n" +
      "    // RUNTIME_UI_HARNESS_RETRY_HOOK_END`n"
    $source = $source.Replace($hook, '')
    $source = $source.Replace(
      '    this.startLiveRuntimeLoop(workflow);',
      "    this.startLiveRuntimeLoop(workflow);`n$($hook.TrimEnd("`n"))"
    )
    [IO.File]::WriteAllText($path, $source, $utf8)
    Sync-Task14CandidateBinding $manifest
  }
  Assert-Task14HarnessRejected 'task14-hilog-obsolete-type' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object { [string]$_.type -eq 'source.hilog.poll' })[0].type =
        'source.hilog'
    }
  }
  Assert-Task14HarnessRejected 'task14-hilog-wrong-argv' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $poll = @($events | Where-Object { [string]$_.type -eq 'source.hilog.poll' })[0]
      $poll.argv[-1] = 'UNREVIEWED_TAG'
    }
  }
  Assert-Task14HarnessRejected 'task14-extra-app-runtime-event-type' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object { [string]$_.type -eq 'service.success' })[0].type =
        'camera.restore'
    }
  }
  Assert-Task14HarnessRejected 'task14-app-payload-self-reported-utc' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $runtime = @($events | Where-Object { [string]$_.type -eq 'service.success' })[0]
      $source = @($events | Where-Object {
          [string]$_.eventId -eq [string]$runtime.sourceCommandEventId
        })[0]
      $source.stdout = ([string]$source.stdout).Replace(
        ',"resultFingerprint"',
        ',"utc":"2026-07-27T00:00:00.0000000Z","resultFingerprint"'
      )
      $source.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes([string]$source.stdout)
      $rawLine = @(([string]$source.stdout -split "`r?`n") | Where-Object {
          $_ -match [regex]::Escape([string]$runtime.eventId)
        })[0]
      $runtime.rawLineSha256 = Get-BytesSha256 $utf8.GetBytes([string]$rawLine)
    }
  }
  Assert-Task14HarnessRejected 'task14-process-timeout-claim' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      @($events | Where-Object { [string]$_.type -eq 'source.capture.screen' })[0].timedOut =
        $true
    }
  }
  Assert-Task14HarnessRejected 'task14-coordinated-capture-path-rewrite' {
    param($manifest, $root)
    $state = $manifest.states[1]
    $decoy = Join-Path (Split-Path -Parent ([string]$state.screenshot)) 'coordinated.jpeg'
    Write-Jpeg $decoy 320 240 'coordinated'
    $hash = (Get-FileHash -LiteralPath $decoy -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($events)
      $capture = @($events | Where-Object {
          [string]$_.type -eq 'capture' -and [string]$_.captureName -eq 'preset-selected'
        })[0]
      $capture.screenshotPath = $decoy
      $capture.screenshotSha256 = $hash
    }
    $state.screenshot = $decoy
    $receipt = Get-Content -LiteralPath ([string]$state.hdcActionReceiptPath) -Raw |
      ConvertFrom-Json
    $receipt.after.screenshotPath = $decoy
    $receipt.after.screenshotSha256 = $hash
    [IO.File]::WriteAllText(
      [string]$state.hdcActionReceiptPath,
      ($receipt | ConvertTo-Json -Depth 30),
      $utf8
    )
    Sync-Task14RunRoot $manifest
  }
  Assert-Task14HarnessRejected 'task14-coordinated-raw-png-content-rewrite' {
    param($manifest, $root)
    $run = Get-Content -LiteralPath ([string]$manifest.runReceiptPath) -Raw |
      ConvertFrom-Json
    $events = @([IO.File]::ReadAllLines([string]$run.transcriptPath) |
        ForEach-Object { $_ | ConvertFrom-Json })
    $capture = @($events | Where-Object {
        [string]$_.type -eq 'capture' -and [string]$_.captureName -eq 'preset-selected'
      })[0]
    $rawPath = [string]$capture.rawScreenshotPath
    Add-Type -AssemblyName System.Drawing
    $bitmap = [Drawing.Bitmap]::new(1320, 2856)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([Drawing.Color]::Magenta)
      $bitmap.Save($rawPath, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
    $rawHash = (Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($rewrittenEvents)
      $rewrittenCapture = @($rewrittenEvents | Where-Object {
          [string]$_.type -eq 'capture' -and
          [string]$_.captureName -eq 'preset-selected'
        })[0]
      $rewrittenCapture.rawScreenshotSha256 = $rawHash
    }
  }
  Assert-Task14HarnessRejected 'task14-picker-false-outcome-not-from-sources' {
    param($manifest, $root)
    $receiptPath = [string]$manifest.states[2].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $outcomePath = [string]$receipt.intermediate.layoutDumpOutcomePath
    [IO.File]::WriteAllText($outcomePath, "recvExitCode=0`n", $utf8)
    $hash = (Get-FileHash -LiteralPath $outcomePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Rewrite-Task14Transcript $manifest {
      param($events)
      $capture = @($events | Where-Object { [string]$_.type -eq 'picker.capture' })[0]
      $capture.layoutDumpOutcomeSha256 = $hash
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $receipt.intermediate.layoutDumpOutcomeSha256 = $hash
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $manifest
  }
  Assert-Task14HarnessRejected 'task14-media-not-settled-three-times' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $observations = @($events | Where-Object {
          [string]$_.type -like 'source.media.after.level*' -and
          [string]$_.mediaDirectory -like '*/Camera' -and
          [string]$_.stdout -match 'task14-saved\.jpg'
        })
      $observations[2].stdout = ''
      $observations[2].stdoutSha256 = Get-BytesSha256 $utf8.GetBytes('')
    }
  }
  Assert-Task14HarnessRejected 'task14-media-one-snapshot-three-duplicate-lines' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $observations = @($events | Where-Object {
          [string]$_.type -like 'source.media.after.level*' -and
          [string]$_.mediaDirectory -like '*/Camera' -and
          [string]$_.stdout -match 'task14-saved\.jpg'
        })
      $line = ([string]$observations[0].stdout).TrimEnd("`r", "`n")
      $observations[0].stdout = "$line`n$line`n$line`n"
      $observations[0].stdoutSha256 =
        Get-BytesSha256 $utf8.GetBytes([string]$observations[0].stdout)
      foreach ($observation in @($observations[1], $observations[2])) {
        $observation.stdout = ''
        $observation.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes('')
      }
    }
  }
  Assert-Task14HarnessRejected 'task14-media-snapshot-no-settle-interval' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $roots = @($events | Where-Object {
          [string]$_.type -eq 'source.media.after.level0'
        })
      $previousSnapshotEvents = @($events | Where-Object {
          [string]$_.type -like 'source.media.after.level*' -and
          [int]$_.sequence -lt [int]$roots[1].sequence
        })
      $roots[1].startedMonotonicTicks =
        [long]$previousSnapshotEvents[-1].endedMonotonicTicks + 1
    }
  }
  Assert-Task14HarnessRejected 'task14-media-size-coordinated-away-from-file' {
    param($manifest, $root)
    Rewrite-Task14Transcript $manifest {
      param($events)
      $asset = @($events | Where-Object { [string]$_.type -eq 'media.asset' })[0]
      $wrongSize = [long]$asset.mediaSize + 1
      $asset.mediaSize = $wrongSize
      foreach ($listing in @($events | Where-Object {
            [string]$_.type -like 'source.media.after.level*' -and
            [string]$_.stdout -match 'task14-saved\.jpg'
          })) {
        $listing.stdout = [regex]::Replace(
          [string]$listing.stdout,
          '(?m)^(-rw\S*\s+)\d+(\s+task14-saved\.jpg)',
          "`${1}$wrongSize`${2}"
        )
        $listing.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes([string]$listing.stdout)
      }
    }
  }
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
  try { Invoke-EvidenceGuard $manifestPath | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "Runtime evidence guard accepted mutation: $Name" }
}

function New-ScrollReachableFixture([string]$Root) {
  $manifestPath = New-Fixture $Root
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  $layoutPath = [string]$manifest.states[0].layout
  $layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding utf8 | ConvertFrom-Json
  $scroll = $layout.children[0].children[0].children[0]
  $longResult = [pscustomobject]@{
    attributes = (Attrs 'Text' '[70,1120][1250,1300]' 'Long scroll result')
    children = @()
  }
  $longResult.attributes.origBounds = '[70,1120][1250,3000]'
  $scroll.children += $longResult
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)

  $afterLayoutPath = Join-Path $Root 'after-scroll.json'
  $afterScreenshotPath = Join-Path $Root 'after-scroll.jpeg'
  $afterLayout = $layout | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $afterLongResult = $afterLayout.children[0].children[0].children[0].children[-1]
  $afterLongResult.attributes.bounds = '[70,500][1250,1300]'
  $afterLongResult.attributes.origBounds = '[70,-800][1250,1300]'
  [IO.File]::WriteAllText($afterLayoutPath, ($afterLayout | ConvertTo-Json -Depth 20), $utf8)
  Write-Jpeg $afterScreenshotPath 1320 2856 'changed'
  $manifest.states[0].requiredTexts = @('Initial', 'Long scroll result')
  $manifest.states[0] | Add-Member -NotePropertyName scrollReachableTexts -NotePropertyValue @(
    [pscustomobject]@{
      selector = 'text:Long scroll result'
      scrollSelector = 'type:Scroll'
      afterScrollLayout = $afterLayoutPath
      afterScrollScreenshot = $afterScreenshotPath
    }
  )
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  return $manifestPath
}

function Assert-ScrollReachableRejected([string]$Name, [scriptblock]$Mutation) {
  $root = Join-Path $tempRoot $Name
  $manifestPath = New-ScrollReachableFixture $root
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
  $layoutPath = [string]$manifest.states[0].layout
  $layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding utf8 | ConvertFrom-Json
  & $Mutation $manifest $layout $root
  [IO.File]::WriteAllText($layoutPath, ($layout | ConvertTo-Json -Depth 20), $utf8)
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $utf8)
  $rejected = $false
  try { Invoke-EvidenceGuard $manifestPath | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "Runtime evidence guard accepted scroll-reachable mutation: $Name" }
}

try {
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  $script:testReviewerRsa = [Security.Cryptography.RSACng]::new(3072)
  $testScriptsRoot = Join-Path $tempRoot 'trusted-test-scripts'
  [IO.Directory]::CreateDirectory($testScriptsRoot) | Out-Null
  $script:testReviewerPublicKeyPath = Join-Path $testScriptsRoot 'runtime-evidence-reviewer-public.pem'
  Export-TestReviewerPublicKey $script:testReviewerRsa $script:testReviewerPublicKeyPath
  $guardPath = Join-Path $testScriptsRoot 'check-runtime-ui-evidence.ps1'
  $captureRunnerPath = Join-Path $testScriptsRoot 'capture-runtime-ui-run.ps1'
  Copy-Item -LiteralPath $productionCaptureRunnerPath -Destination $captureRunnerPath
  Copy-Item -LiteralPath $templateRoot -Destination $testScriptsRoot -Recurse
  $testPem = ([IO.File]::ReadAllText($script:testReviewerPublicKeyPath) -replace
    '-----[^-]+-----', '' -replace '\s', '')
  $testFingerprint = Get-BytesSha256 ([Convert]::FromBase64String($testPem))
  $checkerText = [IO.File]::ReadAllText($productionGuardPath).Replace(
    '8cf68478e1fcb46745e3c7b8a18235caca42c3607eff84d96e8e74dd33f979e6',
    $testFingerprint
  )
  [IO.File]::WriteAllText($guardPath, $checkerText, $utf8)
  $script:mockHdcPath = New-MockHdc (Join-Path $tempRoot 'mock-hdc.exe')
  $validPath = New-Fixture (Join-Path $tempRoot 'valid')
  Invoke-EvidenceGuard $validPath | Out-Null
  $scrollReachableValidPath = New-ScrollReachableFixture (Join-Path $tempRoot 'scroll-reachable-valid')
  Invoke-EvidenceGuard $scrollReachableValidPath | Out-Null
  $task14DefaultPath = Convert-FixtureToTask14Harness (New-Fixture (Join-Path $tempRoot 'task14-harness-default-valid')) 1.0
  Invoke-EvidenceGuard $task14DefaultPath | Out-Null
  $task14Font32Path = Convert-FixtureToTask14Harness (New-Fixture (Join-Path $tempRoot 'task14-harness-font32-valid')) 3.2
  Invoke-EvidenceGuard $task14Font32Path | Out-Null
  if ((Get-Command $productionGuardPath).Parameters.ContainsKey('SelfTestReviewerPublicKeyPath')) {
    throw 'Production runtime evidence checker exposes a reviewer-key override.'
  }
  $productionRejectedTestSignature = $false
  try { Invoke-EvidenceGuard $task14DefaultPath -ProductionTrust | Out-Null }
  catch { $productionRejectedTestSignature = $true }
  if (-not $productionRejectedTestSignature) {
    throw 'Production runtime evidence checker accepted the fixture reviewer key.'
  }
  if ($Mode -eq 'Positive') {
    Write-Output 'Runtime evidence runner and signed positive fixtures passed.'
    return
  }
  Invoke-Task14CoreMutations
  if ($Mode -eq 'Core') {
    Write-Output 'Runtime evidence signed core mutation fixtures passed.'
    return
  }
  $nestedValidPath = Convert-FixtureToNestedProject (
    New-Fixture (Join-Path $tempRoot 'nested-valid')
  )
  Invoke-EvidenceGuard $nestedValidPath | Out-Null
  $nestedManifest = Get-Content -LiteralPath $nestedValidPath -Raw -Encoding utf8 | ConvertFrom-Json
  $nestedManifest.repositoryRoot = Split-Path -Parent ([string]$nestedManifest.repositoryRoot)
  [IO.File]::WriteAllText($nestedValidPath, ($nestedManifest | ConvertTo-Json -Depth 20), $utf8)
  $nestedWrongRootRejected = $false
  try { Invoke-EvidenceGuard $nestedValidPath | Out-Null } catch { $nestedWrongRootRejected = $true }
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
  Assert-Task14HarnessRejected 'task14-source-binding' {
    param($m, $r) $m.source = 'production'
  }
  Assert-Task14HarnessRejected 'task14-route-binding' {
    param($m, $r) $m.routeName = '/hms/ImageSegmentationLiveAnalyseActivity'
  }
  Assert-Task14HarnessRejected 'task14-missing-run-receipt' {
    param($m, $r)
    $m.PSObject.Properties.Remove('runReceiptPath')
    $m.PSObject.Properties.Remove('runReceiptSha256')
  }
  Assert-Task14HarnessRejected 'task14-unanchored-action-receipt-rewrite' {
    param($m, $r)
    $path = [string]$m.states[1].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt | Add-Member -NotePropertyName forged -NotePropertyValue $true
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
  }
  Assert-Task14HarnessRejected 'task14-cross-run-hap-candidate-font-copy' {
    param($m, $r)
    $path = [string]$m.states[1].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.runId = ('f' * 32)
    $receipt.bindings.hapSha256 = ('0' * 64)
    $receipt.bindings.candidateDiffSha256 = ('1' * 64)
    $receipt.bindings.fontScale = 3.2
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-broken-previous-receipt-chain' {
    param($m, $r)
    $path = [string]$m.states[3].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.previousReceiptSha256 = ('0' * 64)
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m $false
  }
  Assert-Task14HarnessRejected 'task14-coordinated-rewrite-without-source-segment' {
    param($m, $r)
    $path = [string]$m.states[1].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.commands[0].stdout = 'forged after capture'
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-fake-no-error-zero-not-from-runner' {
    param($m, $r)
    $path = [string]$m.states[3].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.commands[0].eventId = 'fake-command-not-in-transcript'
    $receipt.commands[0].stdout = 'No Error'
    $receipt.commands[0].exitCode = 0
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-identical-screenshot-synthetic-layout-marker' {
    param($m, $r)
    $preset = $m.states[1]
    $retry = $m.states[6]
    $retry.screenshot = $preset.screenshot
    $path = [string]$retry.hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.after.screenshotPath = $preset.screenshot
    $receipt.after.screenshotSha256 =
      (Get-FileHash -LiteralPath ([string]$preset.screenshot) -Algorithm SHA256).Hash.ToLowerInvariant()
    $layout = Get-Content -LiteralPath ([string]$retry.layout) -Raw -Encoding utf8 | ConvertFrom-Json
    $layout | Add-Member -NotePropertyName marker -NotePropertyValue 'retry-success'
    [IO.File]::WriteAllText([string]$retry.layout, ($layout | ConvertTo-Json -Depth 20), $utf8)
    $receipt.after.layoutSha256 =
      (Get-FileHash -LiteralPath ([string]$retry.layout) -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-screenshot-outside-evidence' {
    param($m, $r)
    $state = $m.states[0]
    $outside = Join-Path $tempRoot 'outside-task14.jpeg'
    Copy-Item -LiteralPath ([string]$state.screenshot) -Destination $outside -Force
    $state.screenshot = $outside
    $path = [string]$state.hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.after.screenshotPath = $outside
    $receipt.after.screenshotSha256 =
      (Get-FileHash -LiteralPath $outside -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-picker-cancel-without-intermediate' {
    param($m, $r)
    $path = [string]$m.states[2].hdcActionReceiptPath
    $receipt = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $receipt.PSObject.Properties.Remove('intermediate')
    [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-decoy-control-id-ancestry' {
    param($m, $r)
    Rewrite-Task14Transcript $m {
      param($events)
      $event = @($events | Where-Object {
          [string]$_.stateName -eq 'preset-selected' -and [string]$_.type -eq 'command'
        })[0]
      $event.target.controlId = 'portrait-decoy-control'
    } $true
  }
  Assert-Task14HarnessRejected 'task14-harness-scope-production-save-edit' {
    param($m, $r)
    $repo = [string]$m.repositoryRoot
    $feature = Join-Path $repo 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
    [IO.File]::AppendAllText(
      $feature,
      'private resultImageSaveBypass(): void {}' + [Environment]::NewLine,
      $utf8
    )
    [IO.File]::WriteAllText(
      [string]$m.candidateDiffPath,
      (Invoke-Git $repo @('diff', '--binary', 'HEAD', '--')),
      $utf8
    )
    $m.candidateDiffSha256 =
      (Get-FileHash -LiteralPath ([string]$m.candidateDiffPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    $canonicalHap = Join-Path $repo 'entry/build/default/outputs/default/entry-default-unsigned.hap'
    & (Join-Path $repo 'scripts/write-runtime-ui-build-receipt.ps1') -HapPath $canonicalHap | Out-Null
    Copy-Item -LiteralPath "$canonicalHap.runtime-ui-build.json" `
      -Destination ([string]$m.buildReceiptPath) -Force
    $build = Get-Content -LiteralPath ([string]$m.buildReceiptPath) -Raw | ConvertFrom-Json
    foreach ($state in @($m.states)) {
      $path = [string]$state.hdcActionReceiptPath
      $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
      $receipt.bindings.candidateDiffSha256 = [string]$m.candidateDiffSha256
      $receipt.bindings.candidateIdentitySha256 = [string]$build.candidateIdentitySha256
      [IO.File]::WriteAllText($path, ($receipt | ConvertTo-Json -Depth 30), $utf8)
    }
    $run = Get-Content -LiteralPath ([string]$m.runReceiptPath) -Raw | ConvertFrom-Json
    $run.candidateDiffSha256 = [string]$m.candidateDiffSha256
    $run.candidateIdentitySha256 = [string]$build.candidateIdentitySha256
    $run.buildReceiptSha256 =
      (Get-FileHash -LiteralPath ([string]$m.buildReceiptPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText([string]$m.runReceiptPath, ($run | ConvertTo-Json -Depth 30), $utf8)
    Sync-Task14RunRoot $m
  }
  Assert-Task14HarnessRejected 'task14-media-asset-empty-size' {
    param($m, $r)
    Rewrite-Task14Transcript $m {
      param($events)
      @($events | Where-Object { $_.type -eq 'media.asset' })[0].mediaSize = 0
    }
  }
  Assert-Task14HarnessRejected 'task14-media-before-already-contains-saved-path' {
    param($m, $r)
    Rewrite-Task14Transcript $m {
      param($events)
      $before = @($events | Where-Object {
          [string]$_.type -like 'source.media.before.level*' -and
          [string]$_.mediaDirectory -like '*/Camera'
        })[0]
      $before.stdout = "-rw-r--r-- 128 task14-saved.jpg`n"
      $before.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes([string]$before.stdout)
    }
  }
  Assert-Task14HarnessRejected 'task14-media-full-path-special-case' {
    param($m, $r)
    Rewrite-Task14Transcript $m {
      param($events)
      $after = @($events | Where-Object {
          [string]$_.type -like 'source.media.after.level*' -and
          [string]$_.mediaDirectory -like '*/Camera'
        })[0]
      $after.stdout =
        "-rw-r--r-- 128 /storage/media/100/local/files/Photo/Camera/task14-saved.jpg`n"
      $after.stdoutSha256 = Get-BytesSha256 $utf8.GetBytes([string]$after.stdout)
    }
  }
  Assert-Task14HarnessRejected 'task14-runtime-event-nonce-run-mismatch' {
    param($m, $r)
    Rewrite-Task14Transcript $m {
      param($events)
      @($events | Where-Object { $_.type -eq 'service.failure' })[0].nonce =
        'foreign-run-nonce'
    }
  }
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
  Assert-ScrollReachableRejected 'scroll-reachable-no-scroll' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].attributes.scrollable = 'false'
  }
  Assert-ScrollReachableRejected 'scroll-reachable-missing-pair' {
    param($m, $l, $r)
    $m.states[0].scrollReachableTexts[0].PSObject.Properties.Remove('afterScrollScreenshot')
  }
  Assert-ScrollReachableRejected 'scroll-reachable-unchanged-screenshot' {
    param($m, $l, $r)
    $afterScreenshot = [string]$m.states[0].scrollReachableTexts[0].afterScrollScreenshot
    Copy-Item -LiteralPath ([string]$m.states[0].screenshot) -Destination $afterScreenshot -Force
  }
  Assert-ScrollReachableRejected 'scroll-reachable-no-global-exemption' {
    param($m, $l, $r)
    $l.children[0].children[0].children[0].children[1].attributes.origBounds = '[70,1120][1250,1600]'
  }

  Write-Output 'Runtime UI evidence guard mutation fixtures passed.'
} finally {
  if ($null -ne $script:testReviewerRsa) { $script:testReviewerRsa.Dispose() }
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
