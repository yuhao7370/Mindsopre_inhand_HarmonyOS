[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConverterPackagePath,
  [switch]$UseWsl,
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\lenet_mnist.ms')
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$archivePath = Join-Path $repositoryRoot 'docs\tutorials\college-hap\college-hap.zip'
$sourceArchivePath = 'artifacts/lenet_mnist.mindir'
$expectedSourceSha256 = '180A5ADAD63856AA6C79397AA319BBA82E919755B6D89B65E447851AF96EE115'
$expectedConverterPackageSha256 = 'DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E'
$expectedConverterSha256 = 'EB9BBA96E1022A8412021DBE4BF07C826F982EC0660E51E512787EE8350663A0'
$expectedOutputSha256 = '4CBF1D2E07C9D2BAD1B742C18AFA55996EA6CC0D335875C5D8E66C9447FD23C3'
$expectedOutputBytes = 182520
$converterArchiveRoot = 'mindspore-lite-2.6.0-linux-x64'
$converterRelativePath = 'tools\converter\converter\converter_lite'

function ConvertTo-WslPath([string]$path) {
  $result = & wsl.exe wslpath -a ($path.Replace('\', '/'))
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($result)) {
    throw "Could not translate Windows path for WSL: $path"
  }
  return $result.Trim()
}

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
  throw "Missing tutorial archive: $archivePath"
}
if (-not (Test-Path -LiteralPath $ConverterPackagePath -PathType Leaf)) {
  throw "Missing official MindSpore Lite converter package: $ConverterPackagePath"
}

$actualConverterPackageSha256 = (Get-FileHash -LiteralPath $ConverterPackagePath -Algorithm SHA256).Hash
if ($actualConverterPackageSha256 -cne $expectedConverterPackageSha256) {
  throw "MindSpore Lite converter package hash mismatch: expected $expectedConverterPackageSha256, got $actualConverterPackageSha256"
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("mnist-mindir-conversion-" + [Guid]::NewGuid().ToString('N'))
$temporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
$outputPath = [IO.Path]::GetFullPath($OutputPath)
$targetDirectory = [IO.Path]::GetDirectoryName($outputPath)
$publishStagePath = Join-Path $targetDirectory ("." + [IO.Path]::GetFileName($outputPath) + "." + [Guid]::NewGuid().ToString('N') + '.tmp')

try {
  New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
  Expand-Archive -LiteralPath $archivePath -DestinationPath $temporaryRoot
  $sourcePath = Join-Path $temporaryRoot $sourceArchivePath
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Tutorial archive does not contain $sourceArchivePath"
  }
  $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
  if ($sourceSha256 -cne $expectedSourceSha256) {
    throw "MindIR source hash mismatch: expected $expectedSourceSha256, got $sourceSha256"
  }

  tar.exe -xzf $ConverterPackagePath -C $temporaryRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Could not extract the verified MindSpore Lite 2.6.0 package (exit code $LASTEXITCODE)"
  }
  $converterPath = Join-Path (Join-Path $temporaryRoot $converterArchiveRoot) $converterRelativePath
  if (-not (Test-Path -LiteralPath $converterPath -PathType Leaf)) {
    throw "Verified MindSpore Lite package does not contain converter_lite: $converterPath"
  }
  $actualConverterSha256 = (Get-FileHash -LiteralPath $converterPath -Algorithm SHA256).Hash
  if ($actualConverterSha256 -cne $expectedConverterSha256) {
    throw "converter_lite hash mismatch: expected $expectedConverterSha256, got $actualConverterSha256"
  }

  $temporaryOutputBase = Join-Path $temporaryRoot 'lenet_mnist'
  if ($UseWsl) {
    $linuxConverterPath = ConvertTo-WslPath $converterPath
    $linuxSourcePath = ConvertTo-WslPath $sourcePath
    $linuxOutputBase = ConvertTo-WslPath $temporaryOutputBase
    $linuxConverterDirectory = (& wsl.exe dirname $linuxConverterPath).Trim()
    $linuxToolsDirectory = (& wsl.exe dirname $linuxConverterDirectory).Trim()
    & wsl.exe env "LD_LIBRARY_PATH=$linuxToolsDirectory/lib" $linuxConverterPath --fmk=MINDIR --modelFile=$linuxSourcePath --outputFile=$linuxOutputBase --saveType=MINDIR_LITE --optimize=general --fp16=off --inputDataFormat=NCHW
  } else {
    & $converterPath --fmk=MINDIR --modelFile=$sourcePath --outputFile=$temporaryOutputBase --saveType=MINDIR_LITE --optimize=general --fp16=off --inputDataFormat=NCHW
  }
  if ($LASTEXITCODE -ne 0) {
    throw "MindSpore Lite converter failed with exit code $LASTEXITCODE"
  }

  $temporaryConvertedPath = "$temporaryOutputBase.ms"
  if (-not (Test-Path -LiteralPath $temporaryConvertedPath -PathType Leaf)) {
    throw "MindSpore Lite converter did not write $temporaryConvertedPath"
  }
  $converted = Get-Item -LiteralPath $temporaryConvertedPath
  $outputSha256 = (Get-FileHash -LiteralPath $temporaryConvertedPath -Algorithm SHA256).Hash
  if ($converted.Length -ne $expectedOutputBytes -or $outputSha256 -cne $expectedOutputSha256) {
    throw "Converted model lock mismatch: expected $expectedOutputBytes bytes / $expectedOutputSha256, got $($converted.Length) bytes / $outputSha256"
  }

  New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
  Copy-Item -LiteralPath $temporaryConvertedPath -Destination $publishStagePath -Force
  $publishedSha256 = (Get-FileHash -LiteralPath $publishStagePath -Algorithm SHA256).Hash
  if ($publishedSha256 -cne $expectedOutputSha256) {
    throw "Staged model hash mismatch: expected $expectedOutputSha256, got $publishedSha256"
  }
  Move-Item -LiteralPath $publishStagePath -Destination $outputPath -Force
  Write-Output "Converted MNIST MindIR: $($converted.Length) bytes, SHA-256 $outputSha256"
} finally {
  if (Test-Path -LiteralPath $publishStagePath) {
    Remove-Item -LiteralPath $publishStagePath -Force
  }
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
