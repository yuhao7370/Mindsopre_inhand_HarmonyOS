[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConverterPath,
  [switch]$UseWsl,
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\lenet_mnist.ms')
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$archivePath = Join-Path $repositoryRoot 'docs\tutorials\college-hap\college-hap.zip'
$sourceArchivePath = 'artifacts/lenet_mnist.mindir'
$expectedSourceSha256 = '180A5ADAD63856AA6C79397AA319BBA82E919755B6D89B65E447851AF96EE115'
$expectedOutputSha256 = '4CBF1D2E07C9D2BAD1B742C18AFA55996EA6CC0D335875C5D8E66C9447FD23C3'
$expectedOutputBytes = 182520

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
  throw "Missing tutorial archive: $archivePath"
}
if (-not (Test-Path -LiteralPath $ConverterPath -PathType Leaf)) {
  throw "Missing MindSpore Lite converter: $ConverterPath"
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("mnist-mindir-conversion-" + [Guid]::NewGuid().ToString('N'))
$temporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
$outputPath = [IO.Path]::GetFullPath($OutputPath)
$outputBase = [IO.Path]::Combine([IO.Path]::GetDirectoryName($outputPath), [IO.Path]::GetFileNameWithoutExtension($outputPath))
$convertedPath = "$outputBase.ms"

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

  New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($outputPath)) -Force | Out-Null
  if ($UseWsl) {
    $toWslPath = {
      param([string]$path)
      $result = & wsl.exe wslpath -a ($path.Replace('\', '/'))
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($result)) {
        throw "Could not translate Windows path for WSL: $path"
      }
      return $result.Trim()
    }
    $linuxConverterPath = & $toWslPath $ConverterPath
    $linuxSourcePath = & $toWslPath $sourcePath
    $linuxOutputBase = & $toWslPath $outputBase
    $linuxConverterDirectory = (& wsl.exe dirname $linuxConverterPath).Trim()
    $linuxToolsDirectory = (& wsl.exe dirname $linuxConverterDirectory).Trim()
    & wsl.exe env "LD_LIBRARY_PATH=$linuxToolsDirectory/lib" $linuxConverterPath --fmk=MINDIR --modelFile=$linuxSourcePath --outputFile=$linuxOutputBase --saveType=MINDIR_LITE --optimize=general --fp16=off --inputDataFormat=NCHW
  } else {
    & $ConverterPath --fmk=MINDIR --modelFile=$sourcePath --outputFile=$outputBase --saveType=MINDIR_LITE --optimize=general --fp16=off --inputDataFormat=NCHW
  }
  if ($LASTEXITCODE -ne 0) {
    throw "MindSpore Lite converter failed with exit code $LASTEXITCODE"
  }
  if (-not (Test-Path -LiteralPath $convertedPath -PathType Leaf)) {
    throw "MindSpore Lite converter did not write $convertedPath"
  }

  $converted = Get-Item -LiteralPath $convertedPath
  $outputSha256 = (Get-FileHash -LiteralPath $convertedPath -Algorithm SHA256).Hash
  if ($converted.Length -ne $expectedOutputBytes -or $outputSha256 -cne $expectedOutputSha256) {
    throw "Converted model lock mismatch: expected $expectedOutputBytes bytes / $expectedOutputSha256, got $($converted.Length) bytes / $outputSha256"
  }

  Write-Output "Converted MNIST MindIR: $($converted.Length) bytes, SHA-256 $outputSha256"
} finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
