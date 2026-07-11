$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'download-image-classification-model.ps1')
& (Join-Path $PSScriptRoot 'download-object-detection-model.ps1')
& (Join-Path $PSScriptRoot 'download-scene-detection-model.ps1')
& (Join-Path $PSScriptRoot 'download-style-transfer-models.ps1')

& (Join-Path $PSScriptRoot 'verify-image-classification-model.ps1')
& (Join-Path $PSScriptRoot 'verify-image-classification-labels.ps1')
& (Join-Path $PSScriptRoot 'verify-object-detection-model.ps1')
& (Join-Path $PSScriptRoot 'verify-object-detection-labels.ps1')
& (Join-Path $PSScriptRoot 'verify-scene-detection-model.ps1')
& (Join-Path $PSScriptRoot 'verify-style-transfer-models.ps1')
