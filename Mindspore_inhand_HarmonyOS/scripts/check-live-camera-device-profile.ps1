$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$cameraPath = Join-Path $root 'entry/src/main/ets/services/camera/LiveCameraService.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $cameraPath) -replace "`r`n", "`n"

function Require-Source([string] $pattern, [string] $message) {
  if ($source -notmatch $pattern) {
    throw $message
  }
}

Require-Source 'manager\.getSupportedCameras\(\)' `
  'Live camera preview must enumerate supported camera devices.'
Require-Source 'camera\.CameraDevice' `
  'Live camera preview must select an actual CameraDevice.'
Require-Source 'getSupportedOutputCapability\([^\n]+camera\.SceneMode\.NORMAL_PHOTO\)' `
  'Live camera preview must query NORMAL_PHOTO output capability for its selected device.'
Require-Source 'previewProfiles\[0\]' `
  'Live camera preview must select a supported preview profile.'
Require-Source 'createCameraInput\([^,\n]+\)' `
  'Live camera preview must create input from the selected CameraDevice.'
Require-Source 'createPreviewOutput\([^,\n]+,\s*surfaceId\)' `
  'Live camera preview must create output from the selected preview profile and surface id.'

if ($source -match 'CameraType\.CAMERA_TYPE_DEFAULT') {
  throw 'Live camera preview must not create camera input from CAMERA_TYPE_DEFAULT.'
}
if ($source -match 'createPreviewOutput\(surfaceId\)') {
  throw 'Live camera preview must not create a profile-less preview output.'
}

Write-Host 'Live camera preview uses a supported device and queried preview profile'
