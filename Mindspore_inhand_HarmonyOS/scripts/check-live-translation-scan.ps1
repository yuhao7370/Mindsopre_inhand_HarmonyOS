$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $projectRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$pickerPath = Join-Path $projectRoot 'entry\src\main\ets\services\picker\PickerService.ets'
$cameraPath = Join-Path $projectRoot 'entry\src\main\ets\services\camera\LiveCameraService.ets'
$pagePath = Join-Path $projectRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$stringsPath = Join-Path $projectRoot 'entry\src\main\ets\common\i18n\AppStrings.ets'
$resourcePaths = @(
  (Join-Path $projectRoot 'entry\src\main\resources\base\element\string.json'),
  (Join-Path $projectRoot 'entry\src\main\resources\en_US\element\string.json'),
  (Join-Path $projectRoot 'entry\src\main\resources\zh_CN\element\string.json')
)

$catalog = Get-Content -LiteralPath $catalogPath -Raw
$picker = Get-Content -LiteralPath $pickerPath -Raw
$camera = Get-Content -LiteralPath $cameraPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$strings = Get-Content -LiteralPath $stringsPath -Raw

function Assert-Contains([string]$content, [string]$expected, [string]$description) {
  $normalizedContent = $content -replace "`r`n", "`n"
  if (-not $normalizedContent.Contains($expected)) {
    throw "Live translation scan guard failed: $description"
  }
}

Assert-Contains $catalog "'liveCamera' |" 'FeatureInputKind must define a separate liveCamera input.'
Assert-Contains $catalog "inputKinds: ['text', 'camera', 'photo', 'liveCamera']" 'Text Translation must keep Android text/camera/photo inputs and add liveCamera.'
Assert-Contains $catalog "case 'liveCamera':`n      return 'feature_input_live_translation';" 'liveCamera must have a localized input label.'
Assert-Contains $catalog 'export function liveRuntimeModeForWorkflow(' 'Live mode selection must be testable outside the page.'
Assert-Contains $catalog 'export function runtimeTextInputForWorkflow(' 'Live translation must suppress stale typed text before AI execution.'
Assert-Contains $catalog 'export function shouldRenderLiveCameraPreview(' 'Hybrid workflows must gate preview rendering by active live state.'
Assert-Contains $catalog 'export function isInputPreparationRequestCurrent(' 'Input request ordering must be testable outside the page.'
Assert-Contains $picker "case 'liveCamera':`n      return 'startLiveCamera';" 'liveCamera must use the real camera preview, not the still-image picker.'
Assert-Contains $camera "aiMethod === 'translateText'" 'The live runtime loop must support OCR-plus-translation.'
Assert-Contains $page 'liveRuntimeModeForWorkflow(workflow, this.liveCameraInputSelected)' 'All live loop entry points must use the tested live-mode decision.'
Assert-Contains $page 'text: runtimeTextInputForWorkflow(' 'AI inputs must ignore stale typed text during live translation.'
Assert-Contains $page 'shouldRenderLiveCameraPreview(' 'The page must hide hybrid live preview until live mode is active.'
Assert-Contains $page 'private liveCameraPreviewRequestId: number = 0;' 'Camera preview starts must carry a lifecycle request id.'
Assert-Contains $page 'private liveRuntimeGeneration: number = 0;' 'Live inference sessions must carry a generation id.'
Assert-Contains $page 'private inputPreparationRequestId: number = 0;' 'Input preparation must carry a request id.'
Assert-Contains $page 'const requestId = ++this.liveCameraPreviewRequestId;' 'Each preview start must create a new lifecycle request.'
Assert-Contains $page 'requestId !== this.liveCameraPreviewRequestId' 'Stale async preview completions must be rejected.'
Assert-Contains $page 'await this.stopLiveCameraPreviewAsync();' 'Still-image inputs must wait for live camera hardware to be released.'
Assert-Contains $page 'isLiveRuntimeGenerationCurrent(liveGeneration, this.liveRuntimeGeneration)' 'Stale live inference frames must be rejected before mutating page state.'
Assert-Contains $page 'isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)' 'Stale input requests must stop after asynchronous work.'
Assert-Contains $page 'this.inputPreparationRequestId++;' 'Leaving the page must invalidate pending input requests.'
$replaceInputStart = $page.IndexOf('} else if (inputKindReplacesPrimaryInput(inputKind)) {')
$replaceInputEnd = $page.IndexOf("if (inputKind === 'text')", $replaceInputStart)
if ($replaceInputStart -lt 0 -or $replaceInputEnd -le $replaceInputStart) {
  throw 'Live translation scan guard failed: primary input replacement branch is missing.'
}
$replaceInputBranch = $page.Substring($replaceInputStart, $replaceInputEnd - $replaceInputStart)
Assert-Contains $replaceInputBranch 'await this.stopLiveCameraPreviewAsync();' 'Replacing live input must release the camera before still pickers run.'
$liveInputStart = $page.IndexOf("if (liveCameraInput) {", $page.IndexOf("if (inputKind === 'text')"))
$liveInputEnd = $page.IndexOf("if (inputKind === 'sampleImage')", $liveInputStart)
if ($liveInputStart -lt 0 -or $liveInputEnd -le $liveInputStart) {
  throw 'Live translation scan guard failed: live camera input branch is missing.'
}
$liveInputBranch = $page.Substring($liveInputStart, $liveInputEnd - $liveInputStart)
Assert-Contains $liveInputBranch 'this.textInputVisible = false;' 'Starting live translation must hide the typed editor.'
Assert-Contains $liveInputBranch 'this.startLiveCameraPreview();' 'Starting live translation must use the real preview, not the still picker.'
Assert-Contains $page "textInputVisibleAfterCancelledPick(`n        workflow,`n        'liveCamera'" 'A failed live start must restore the prior typed editor state.'
Assert-Contains $page "if (this.liveCameraInputSelected) {`n              this.startLiveCameraPreview();" 'Hybrid preview must start after its XComponent surface loads.'
Assert-Contains $strings "'feature_input_live_translation' |" 'AppStrings must expose the live translation key.'
Assert-Contains $strings "case 'feature_input_live_translation':" 'AppStrings must map the live translation resource.'

foreach ($resourcePath in $resourcePaths) {
  $resource = Get-Content -LiteralPath $resourcePath -Raw
  Assert-Contains $resource '"name": "feature_input_live_translation"' "$(Split-Path -Leaf $resourcePath) must localize live translation."
}

Write-Output 'Live translation scan guard passed.'
