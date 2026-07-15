param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'

$models = @(
  [pscustomobject]@{
    Name = 'style_predict_quant.ms'
    Url = 'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms'
    Bytes = 3022576
    Sha256 = '6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC'
  },
  [pscustomobject]@{
    Name = 'style_transfer_quant.ms'
    Url = 'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms'
    Bytes = 256864
    Sha256 = 'AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682'
  }
)

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

foreach ($model in $models) {
  $modelPath = Join-Path $modelDir $model.Name
  $tmpPath = Join-Path $modelDir "$($model.Name).download.$([System.Guid]::NewGuid().ToString('N'))"
  $backupPath = "$tmpPath.backup"

  if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
    $size = (Get-Item -LiteralPath $modelPath).Length
    Write-Host "$($model.Name) already exists: $modelPath ($size bytes)"
    continue
  }

  try {
    Write-Host "Downloading $($model.Url)"
    Invoke-WebRequest -Uri $model.Url -OutFile $tmpPath

    $downloadedSize = (Get-Item -LiteralPath $tmpPath).Length
    if ($downloadedSize -ne $model.Bytes) {
      throw "Downloaded $($model.Name) has $downloadedSize bytes; expected $($model.Bytes) bytes."
    }
    $downloadedSha256 = (Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash
    if ($downloadedSha256 -cne $model.Sha256) {
      throw "Downloaded $($model.Name) SHA256 $downloadedSha256 does not match expected $($model.Sha256)."
    }

    if (Test-Path -LiteralPath $modelPath) {
      [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
    } else {
      [System.IO.File]::Move($tmpPath, $modelPath)
    }
    Write-Host "$($model.Name) downloaded: $modelPath ($downloadedSize bytes)"
  } catch {
    $failure = $_
    if ((Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $modelPath)) {
      [System.IO.File]::Move($backupPath, $modelPath)
    }
    throw $failure
  } finally {
    Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $modelPath) {
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
  }
}
