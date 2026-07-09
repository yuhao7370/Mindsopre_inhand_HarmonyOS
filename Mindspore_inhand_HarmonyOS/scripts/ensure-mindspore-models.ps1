$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'download-image-classification-model.ps1')
& (Join-Path $PSScriptRoot 'download-object-detection-model.ps1')
& (Join-Path $PSScriptRoot 'download-style-transfer-models.ps1')

& (Join-Path $PSScriptRoot 'verify-image-classification-model.ps1')
& (Join-Path $PSScriptRoot 'verify-object-detection-model.ps1')
& (Join-Path $PSScriptRoot 'verify-style-transfer-models.ps1')
