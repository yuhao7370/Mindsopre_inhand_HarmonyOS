param(
  [Parameter(Mandatory = $true)][string]$Python,
  [Parameter(Mandatory = $true)][string]$Venv,
  [string]$Wheelhouse = (Join-Path $env:TEMP 'translation-t3-wheelhouse')
)

$ErrorActionPreference = 'Stop'
$torchName = 'torch-2.5.1+cu121-cp39-cp39-win_amd64.whl'
$torchUrl = 'https://download.pytorch.org/whl/cu121/torch-2.5.1%2Bcu121-cp39-cp39-win_amd64.whl'
$torchBytes = 2449296180
$torchSha256 = 'DC4249C520A6E9B1555E46BD70586A7CF33012800A51ACB58A0C51464E3A786A'
New-Item -ItemType Directory -Force -Path $Wheelhouse | Out-Null
$torchWheel = Join-Path $Wheelhouse $torchName
if (-not (Test-Path -LiteralPath $torchWheel)) {
  & curl.exe --ssl-no-revoke -L --fail --output $torchWheel $torchUrl
  if ($LASTEXITCODE -ne 0) { throw 'Pinned CUDA torch wheel download failed' }
}
$torchFile = Get-Item -LiteralPath $torchWheel
$torchHash = (Get-FileHash -LiteralPath $torchWheel -Algorithm SHA256).Hash
if ($torchFile.Length -ne $torchBytes -or $torchHash -ne $torchSha256) {
  throw 'Pinned CUDA torch wheel integrity failure'
}
& $Python -m venv $Venv
$venvPython = Join-Path $Venv 'Scripts\python.exe'
& $venvPython -m pip install --no-deps $torchWheel
if ($LASTEXITCODE -ne 0) { throw 'Pinned CUDA torch wheel installation failed' }
& $venvPython -m pip install --require-hashes --only-binary=:all: `
  --extra-index-url https://download.pytorch.org/whl/cu121 `
  -r (Join-Path $PSScriptRoot 'requirements-t3.lock.txt')
if ($LASTEXITCODE -ne 0) { throw 'T3 dependency installation failed' }
& $venvPython -c "import torch; assert torch.__version__ == '2.5.1+cu121'; assert torch.version.cuda == '12.1'; assert torch.cuda.is_available()"
if ($LASTEXITCODE -ne 0) { throw 'T3 CUDA verification failed' }
