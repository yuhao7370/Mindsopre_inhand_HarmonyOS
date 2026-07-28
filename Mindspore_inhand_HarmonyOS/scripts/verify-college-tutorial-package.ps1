[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$expectedLength = 11095055
$expectedSha256 = '9D556E96FE27357B90FDC3814C5AB707FCEF8EED314981A6552B2A11B8C7DE42'
$requiredEntries = @(
  '01-environment.md', '02-data.md', '03-network.md', '04-training.md', '05-export.md',
  'mnist-lenet.py',
  'artifacts/lenet_mnist.ckpt', 'artifacts/lenet_mnist.mindir',
  'data/MNIST/train-images-idx3-ubyte', 'data/MNIST/train-labels-idx1-ubyte',
  'data/MNIST/t10k-images-idx3-ubyte', 'data/MNIST/t10k-labels-idx1-ubyte'
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$paths = @(
  (Join-Path $projectRoot 'docs/tutorials/college-hap/college-hap.zip'),
  (Join-Path $projectRoot 'entry/src/main/resources/rawfile/college/college-hap.zip')
)

foreach ($path in $paths) {
  $file = Get-Item -LiteralPath $path
  if ($file.Length -ne $expectedLength) { throw "Unexpected length for ${path}: $($file.Length)" }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  if ($hash -ne $expectedSha256) { throw "Unexpected SHA-256 for ${path}: $hash" }
  $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
  try {
    $entries = @($archive.Entries | ForEach-Object FullName)
    foreach ($entry in $requiredEntries) {
      if ($entries -notcontains $entry) { throw "Missing ZIP entry in ${path}: $entry" }
    }
  } finally {
    $archive.Dispose()
  }
  Write-Host "Verified $path"
}
