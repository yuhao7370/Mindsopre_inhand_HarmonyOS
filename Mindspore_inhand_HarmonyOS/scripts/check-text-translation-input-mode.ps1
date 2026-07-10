$ErrorActionPreference = 'Stop'

$pagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
$source = Get-Content -Raw -Encoding UTF8 $pagePath

function Get-SourceSlice([string] $text, [string] $startMarker, [string] $endMarker) {
  $start = $text.IndexOf($startMarker)
  if ($start -lt 0) {
    throw "Missing source marker: $startMarker"
  }
  $end = $text.IndexOf($endMarker, $start + $startMarker.Length)
  if ($end -lt 0) {
    throw "Missing source marker: $endMarker"
  }
  return $text.Substring($start, $end - $start)
}

$prepareInput = Get-SourceSlice `
  $source `
  'private prepareInput(inputKind: FeatureInputKind): void' `
  'private cacheAndApplyPickedModelFile'
$applyPickResult = Get-SourceSlice `
  $source `
  'private applyPickResult(result: PickResult, readyKey: AppStringKey, inputKind: FeatureInputKind): void' `
  'private aiRunInputs()'

if ($prepareInput -notmatch "(?s)if\s*\(inputKind === 'text'\)\s*\{\s*this\.textInputVisible = true;") {
  throw 'Text input mode must restore the runtime text editor before returning.'
}

$actionIndex = $applyPickResult.IndexOf('const inputReadyAction = workflowInputReadyAction(workflow, inputKind, this.userText);')
$textIndex = $applyPickResult.IndexOf('this.userText = inputReadyAction.userText;')
$visibilityIndex = $applyPickResult.IndexOf('this.textInputVisible = inputReadyAction.textInputVisible;')
$runIndex = $applyPickResult.IndexOf('if (inputReadyAction.shouldRunWorkflow)')

if ($actionIndex -lt 0) {
  throw 'Successful picker input must compute workflowInputReadyAction.'
}
if ($textIndex -lt $actionIndex) {
  throw 'Successful picker input must apply userText from workflowInputReadyAction.'
}
if ($visibilityIndex -lt $textIndex) {
  throw 'Successful picker input must apply textInputVisible after userText.'
}
if ($runIndex -lt $visibilityIndex) {
  throw 'Successful picker input must update text input visibility before runWorkflow().'
}

if ($source.IndexOf("if (this.inputKinds.indexOf('text') >= 0 && this.textInputVisible)") -lt 0) {
  throw 'Runtime text editor must render only when the workflow supports text input and textInputVisible is true.'
}

Write-Output 'Text translation input-mode wiring is attached to FeatureRuntimePage.'
