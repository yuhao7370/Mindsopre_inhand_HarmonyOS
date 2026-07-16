[CmdletBinding()]
param(
  [string]$DevEcoSdkRoot = '',
  [string]$LibraryPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '..'))
$nativeRoot = Join-Path $projectRoot 'entry\src\main\cpp\translation_xz'
if (-not $LibraryPath) { $LibraryPath = Join-Path $projectRoot 'entry\libs\arm64-v8a\libtranslation_archive.so' }

function Assert-Contains([string]$Path, [string]$Pattern, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing $Label`: $Path" }
  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -notmatch $Pattern) { throw "$Label contract missing: $Pattern" }
}

function Resolve-NativeSdk([string]$Requested) {
  foreach ($candidate in @($Requested, $env:DEVECO_SDK_HOME, 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony')) {
    if (-not $candidate) { continue }
    $root = [IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath (Join-Path $root 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $root }
    $defaultOpenHarmony = Join-Path $root 'default\openharmony'
    if (Test-Path -LiteralPath (Join-Path $defaultOpenHarmony 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $defaultOpenHarmony }
    $nested = Join-Path $root 'openharmony'
    if (Test-Path -LiteralPath (Join-Path $nested 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $nested }
  }
  throw 'HarmonyOS native SDK not found.'
}

function Get-ExpectedMachine([string]$ReadelfOutput) {
  if ($ReadelfOutput -match '(?m)^\s*Machine:\s*(.+?)\s*$') {
    $machine = $matches[1]
    if ($machine -eq 'AArch64') { return 'AArch64' }
    if ($machine -eq 'Advanced Micro Devices X86-64') { return 'Advanced Micro Devices X86-64' }
    return $machine
  }
  throw 'Unable to determine ELF machine from llvm-readelf output.'
}

$required = @(
  (Join-Path $repositoryRoot 'tools\translation\build_xz_ohos.ps1'),
  (Join-Path $nativeRoot 'CMakeLists.txt'),
  (Join-Path $nativeRoot 'translation_xz_extract.h'),
  (Join-Path $nativeRoot 'translation_xz_extract.cpp'),
  (Join-Path $nativeRoot 'translation_xz_napi.cpp'),
  (Join-Path $projectRoot 'entry\src\main\ets\native\translation_xz\index.d.ts')
)
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing translation XZ prerequisite: $path" }
}

$extract = Join-Path $nativeRoot 'translation_xz_extract.cpp'
$napi = Join-Path $nativeRoot 'translation_xz_napi.cpp'
Assert-Contains $extract '32\s*\*\s*1024\s*\*\s*1024' '32 MiB compressed cap'
Assert-Contains $extract '60\s*\*\s*1024\s*\*\s*1024' '60 MiB output cap'
Assert-Contains $extract '68\s*\*\s*1024\s*\*\s*1024' '68 MiB liblzma cap'
Assert-Contains $extract 'FitsOutputAddition' 'checked output accumulation helper'
Assert-Contains $extract 'kMaxOutputBytes\s*\+\s*1' 'first-member cap-plus-one negative'
Assert-Contains $extract 'kMaxOutputBytes\s*-\s*1[\s\S]{0,80},\s*2' 'accumulated overflow negative'
Assert-Contains $extract '9007199254740991' 'JavaScript safe-maximum negative'
Assert-Contains $extract 'kMaxOutputBytes\s*-\s*2' 'exact-cap three-member boundary'
Assert-Contains $extract 'lzma_stream_decoder' 'single-stream decoder'
Assert-Contains $extract 'LZMA_CHECK_CRC64' 'CRC64 requirement'
Assert-Contains $extract 'lzma_get_check' 'decoded check inspection'
Assert-Contains $extract 'pread' 'bounded FD range input'
Assert-Contains $extract 'encoder\.ms' 'encoder allowlist'
Assert-Contains $extract 'decoder_prefill\.ms' 'prefill allowlist'
Assert-Contains $extract 'decoder_step\.ms' 'step allowlist'
Assert-Contains $extract "S_ISREG|typeFlag[\s\S]{0,120}!=\s*'0'" 'regular member enforcement'
Assert-Contains $extract 'duplicate|seen' 'duplicate rejection'
Assert-Contains $extract 'trailing|unused|avail_in' 'trailing-data rejection'
Assert-Contains $extract 'rename\(' 'atomic publish'
Assert-Contains $extract 'remove_all' 'partial cleanup'
Assert-Contains $extract 'archiveSha256' 'SHA-keyed cache'
Assert-Contains $extract 'O_NOFOLLOW|symlink_status' 'path/symlink safety'
if ((Get-Content -LiteralPath $extract -Raw) -match 'LZMA_CONCATENATED') {
  throw 'The native decoder must not enable concatenated XZ streams.'
}

Assert-Contains $napi 'napi_create_async_work' 'async NAPI'
Assert-Contains $napi 'dup\(' 'FD lifetime ownership'
Assert-Contains $napi 'isfinite' 'finite numeric request validation'
Assert-Contains $napi 'trunc' 'integer request validation'
Assert-Contains $napi 'INT_MAX' 'FD narrowing validation'
Assert-Contains $napi 'napi_delete_async_work' 'async cleanup'
Assert-Contains $napi 'napi_reject_deferred' 'Promise rejection'
Assert-Contains $napi 'napi_fatal_error' 'unrecoverable cleanup terminal path'
Assert-Contains $napi 'work\.reset\(' 'owned context cleanup'

if (-not (Test-Path -LiteralPath $LibraryPath -PathType Leaf)) { throw "Missing built translation archive library: $LibraryPath" }
$sdk = Resolve-NativeSdk $DevEcoSdkRoot
$readelf = Join-Path $sdk 'native\llvm\bin\llvm-readelf.exe'
$elf = & $readelf -h -d $LibraryPath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "llvm-readelf failed:`n$elf" }
$machine = Get-ExpectedMachine $elf
if (@('AArch64', 'Advanced Micro Devices X86-64') -notcontains $machine) {
  throw "Translation archive machine not supported for runtime: $machine"
}
$dependencies = @([regex]::Matches($elf, '\(NEEDED\).*\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$expected = @('libace_napi.z.so', 'libohcrypto.so', 'libc++_shared.so', 'libc.so') | Sort-Object
if (($dependencies -join '|') -cne ($expected -join '|')) {
  throw "Translation archive DT_NEEDED mismatch: expected $($expected -join ', '), got $($dependencies -join ', ')"
}

Write-Output "Translation XZ native contract verified: $LibraryPath"
