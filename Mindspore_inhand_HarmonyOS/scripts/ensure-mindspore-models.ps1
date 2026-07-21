$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'verify-image-classification-model.ps1')
& (Join-Path $PSScriptRoot 'verify-image-classification-labels.ps1')
& (Join-Path $PSScriptRoot 'verify-object-detection-model.ps1')
& (Join-Path $PSScriptRoot 'verify-object-detection-labels.ps1')
& (Join-Path $PSScriptRoot 'verify-scene-detection-model.ps1')
& (Join-Path $PSScriptRoot 'verify-style-transfer-models.ps1')
& (Join-Path $PSScriptRoot 'verify-custom-model-fixtures.ps1')
& (Join-Path $PSScriptRoot 'verify-posenet-model.ps1')
