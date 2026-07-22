[CmdletBinding()]
param([string]$Python = 'python')

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location $repositoryRoot
try {
  & $Python -m unittest tools.translation.test_open_source_edge_models -v
  if ($LASTEXITCODE -ne 0) { throw 'Open-source edge translation guard failed.' }
} finally {
  Pop-Location
}
