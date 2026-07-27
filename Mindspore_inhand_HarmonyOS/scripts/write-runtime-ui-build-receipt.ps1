param(
  [Parameter(Mandatory = $true)]
  [string]$HapPath
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$HapPath = [IO.Path]::GetFullPath($HapPath)
$canonicalHapPath = Join-Path $repositoryRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
if ($HapPath -ine [IO.Path]::GetFullPath($canonicalHapPath) -or
  -not (Test-Path -LiteralPath $HapPath -PathType Leaf)) {
  throw 'Runtime UI build receipt requires the canonical main HAP.'
}

function Normalize-ReceiptText([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
}

function Get-ReceiptTextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes((Normalize-ReceiptText $Text))
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

$gitHead = Normalize-ReceiptText (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot rev-parse HEAD 2>$null) -join "`n"
)
if ($LASTEXITCODE -ne 0 -or $gitHead -notmatch '^[0-9a-f]{40}$') {
  throw 'Runtime UI build receipt could not resolve repository HEAD.'
}
$gitStatus = Normalize-ReceiptText (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      status --porcelain=v1 --untracked-files=all 2>$null) -join "`n"
)
$gitDiff = Normalize-ReceiptText (
  (& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot `
      diff --binary HEAD -- 2>$null) -join "`n"
)
$candidateKind = if ([string]::IsNullOrEmpty($gitStatus)) { 'commit' } else { 'workingTree' }
$candidateIdentitySha256 = if ($candidateKind -eq 'commit') {
  Get-ReceiptTextSha256 $gitHead
} else {
  Get-ReceiptTextSha256 $gitDiff
}

Add-Type -AssemblyName System.IO.Compression
$file = [IO.File]::OpenRead($HapPath)
$archive = $null
try {
  $archive = [IO.Compression.ZipArchive]::new(
    $file,
    [IO.Compression.ZipArchiveMode]::Read,
    $false
  )
  $moduleMatches = @($archive.Entries | Where-Object {
      $_.FullName.Replace('\', '/') -ceq 'ets/modules.abc'
    })
  if ($moduleMatches.Count -ne 1 -or $moduleMatches[0].Length -le 0) {
    throw 'Runtime UI build receipt requires one non-empty ets/modules.abc entry.'
  }
  $moduleStream = $moduleMatches[0].Open()
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $moduleAbcSha256 =
      ([BitConverter]::ToString($sha.ComputeHash($moduleStream))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
    $moduleStream.Dispose()
  }
  $abis = @($archive.Entries | ForEach-Object {
      $name = $_.FullName.Replace('\', '/')
      if ($name -match '^libs/([^/]+)/[^/]+\.so$') { $matches[1] }
    } | Sort-Object -Unique)
} finally {
  if ($null -ne $archive) { $archive.Dispose() }
  $file.Dispose()
}

$buildProfilePath = Join-Path $repositoryRoot 'entry\build-profile.json5'
$receiptWriterPath = Join-Path $repositoryRoot 'scripts\write-runtime-ui-build-receipt.ps1'
$receipt = [ordered]@{
  schemaVersion = 1
  repositoryRoot = $repositoryRoot
  gitHead = $gitHead
  gitStatusSha256 = Get-ReceiptTextSha256 $gitStatus
  candidateKind = $candidateKind
  candidateIdentitySha256 = $candidateIdentitySha256
  hapSha256 = (Get-FileHash -LiteralPath $HapPath -Algorithm SHA256).Hash.ToLowerInvariant()
  moduleAbcSha256 = $moduleAbcSha256
  buildProfileSha256 =
    (Get-FileHash -LiteralPath $buildProfilePath -Algorithm SHA256).Hash.ToLowerInvariant()
  receiptWriterSha256 =
    (Get-FileHash -LiteralPath $receiptWriterPath -Algorithm SHA256).Hash.ToLowerInvariant()
  abis = $abis
}
$receiptPath = "$HapPath.runtime-ui-build.json"
[IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 10), $utf8)
Write-Output "Runtime UI build receipt written: $receiptPath"
