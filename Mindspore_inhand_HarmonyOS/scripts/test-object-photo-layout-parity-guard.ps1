$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $PSScriptRoot
$guardPath = Join-Path $PSScriptRoot 'check-object-photo-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $tempParent ("object-photo-layout-guard-" + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$nl = "`n"

function Copy-GuardSources {
  $relativePaths = @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'scripts\build-hap.ps1'
  )
  foreach ($relativePath in $relativePaths) {
    $targetPath = Join-Path $fixtureRoot $relativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $targetPath)) | Out-Null
    [IO.File]::Copy((Join-Path $sourceRoot $relativePath), $targetPath, $true)
  }
}

function Replace-Once([string]$RelativePath, [string]$OldText, [string]$NewText) {
  $path = Join-Path $fixtureRoot $RelativePath
  $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
  $OldText = $OldText.Replace("`r`n", "`n").Replace("`r", "`n")
  $NewText = $NewText.Replace("`r`n", "`n").Replace("`r", "`n")
  $first = $text.IndexOf($OldText, [StringComparison]::Ordinal)
  $last = $text.LastIndexOf($OldText, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $first -ne $last) {
    throw "Fixture mutation must match exactly once: $RelativePath"
  }
  [IO.File]::WriteAllText($path, $text.Substring(0, $first) + $NewText +
    $text.Substring($first + $OldText.Length), $utf8)
}

function Assert-GuardRejectsMutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$OldText,
  [string]$NewText
) {
  Copy-GuardSources
  Replace-Once $RelativePath $OldText $NewText
  $rejected = $false
  try {
    & $guardPath -SourceRoot $fixtureRoot *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Object Photo guard fixture failed: source mutation was accepted ($Name)."
  }
}

try {
  Copy-GuardSources
  & $guardPath -SourceRoot $fixtureRoot *> $null

  $builderStart = '  objectPhotoAndroidLayout() {' + $nl +
    '    Column() {' + $nl +
    '      this.runtimeActionToolbar(true)'
  $builderWithGenericCard = $builderStart + $nl +
    "      Text(appString('feature_runtime_inputs_title'))"
  Assert-GuardRejectsMutation 'genericInputCard' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' $builderStart $builderWithGenericCard
  $builderWithPermissionCard = $builderStart + $nl +
    "      Text(appString('feature_runtime_permissions_title'))"
  Assert-GuardRejectsMutation 'genericPermissionCard' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' $builderStart $builderWithPermissionCard
  $builderWithDebugCard = $builderStart + $nl +
    "      Text(appString('feature_runtime_debug'))"
  Assert-GuardRejectsMutation 'genericDebugCard' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' $builderStart $builderWithDebugCard

  Assert-GuardRejectsMutation 'toastPolicy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' '    const toastKey = objectPhotoResultToastKey(workflowForRoute(this.routeName), resultOk);' "    const toastKey = 'objectPhotoResultToastKey(workflowForRoute(this.routeName), resultOk)';"

  $staleGate = '    if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {' + $nl +
    '      return;' + $nl +
    '    }' + $nl +
    '    if (cacheResult === undefined) {'
  $staleGateDecoy = "    if ('if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {'.length > 0) {" + $nl +
    '      return;' + $nl +
    '    }' + $nl +
    '    if (cacheResult === undefined) {'
  Assert-GuardRejectsMutation 'cacheStaleGate' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' $staleGate $staleGateDecoy

  Assert-GuardRejectsMutation 'cacheApply' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' '    this.applyModelFileCacheResult(cacheResult, inputKind);' "    const applyDecoy = 'this.applyModelFileCacheResult(cacheResult, inputKind);';"

  Assert-GuardRejectsMutation 'followupPolicy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' '    const followupInputKind = objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind);' "    const followupInputKind = 'objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind)';"

  Assert-GuardRejectsMutation 'followupInitialPick' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' '      this.prepareInput(followupInputKind, true);' "      const initialPickDecoy = 'this.prepareInput(followupInputKind, true);';"

  Assert-GuardRejectsMutation 'buildSelector' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' '    } else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {' "    } else if ('usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))'.length > 0) {"

  Assert-GuardRejectsMutation 'buildGuardCall' 'scripts\build-hap.ps1' '& (Join-Path $PSScriptRoot ''check-object-photo-layout-parity.ps1'')' '$guardCallDecoy = "& (Join-Path $PSScriptRoot ''check-object-photo-layout-parity.ps1'')"'

  Write-Output 'Object Photo layout guard negative fixtures passed.'
} finally {
  $resolvedFixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
  if ($resolvedFixtureRoot.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($resolvedFixtureRoot)) {
    [IO.Directory]::Delete($resolvedFixtureRoot, $true)
  }
}
