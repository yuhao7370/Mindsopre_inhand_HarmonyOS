[CmdletBinding()]
param(
  [string]$DevEcoSdkRoot = '',
  [string]$LibraryPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cppRoot = Join-Path $projectRoot 'entry\src\main\cpp'
if (-not $LibraryPath) {
  $LibraryPath = Join-Path $projectRoot 'entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgesture_mnn.so'
}

function Resolve-NativeSdk([string]$RequestedRoot) {
  $candidates = @($RequestedRoot, $env:DEVECO_SDK_HOME, 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony')
  foreach ($candidate in $candidates) {
    if (-not $candidate) { continue }
    $root = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath (Join-Path $root 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $root }
    $openharmony = Join-Path $root 'openharmony'
    if (Test-Path -LiteralPath (Join-Path $openharmony 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $openharmony }
  }
  throw 'HarmonyOS native SDK not found.'
}

function Assert-Contains([string]$Path, [string]$Pattern, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing $Label`: $Path" }
  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -notmatch $Pattern) { throw "$Label contract missing: $Pattern" }
}

$required = @(
  (Join-Path $cppRoot 'CMakeLists.txt'),
  (Join-Path $cppRoot 'gesture_mnn_session.h'),
  (Join-Path $cppRoot 'gesture_mnn_session.cpp'),
  (Join-Path $cppRoot 'gesture_mnn_napi.cpp'),
  (Join-Path $cppRoot 'types\libgesture_mnn\index.d.ts'),
  (Join-Path $cppRoot 'types\libgesture_mnn\oh-package.json5')
)
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing native gesture contract file: $path" }
}

$napi = Join-Path $cppRoot 'gesture_mnn_napi.cpp'
$session = Join-Path $cppRoot 'gesture_mnn_session.cpp'
Assert-Contains $napi 'napi_create_async_work' 'async NAPI'
Assert-Contains $napi 'napi_float32_array' 'Float32Array validation'
Assert-Contains $napi '150528' 'input length validation'
Assert-Contains $session 'layer89-conv-hand' 'stride-32 output'
Assert-Contains $session 'layer101-conv-hand' 'stride-16 output'
Assert-Contains $session 'layer113-conv-hand' 'stride-8 output'
Assert-Contains $session 'std::mutex' 'serialized session'
Assert-Contains $session 'std::vector<uint8_t>\(\)\.swap\(modelBytes_\)' 'no-throw retained-byte release'
if ((Get-Content -LiteralPath $session -Raw) -match 'shrink_to_fit') {
  throw 'release() must not call potentially-throwing shrink_to_fit().'
}

if (-not (Test-Path -LiteralPath $LibraryPath -PathType Leaf)) {
  throw "Missing built gesture NAPI library: $LibraryPath"
}
$nativeSdk = Resolve-NativeSdk $DevEcoSdkRoot
$readelf = Join-Path $nativeSdk 'native\llvm\bin\llvm-readelf.exe'
$dynamic = & $readelf -h -d $LibraryPath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "llvm-readelf failed:`n$dynamic" }
if ($dynamic -notmatch '(?m)^\s*Machine:\s+AArch64\s*$') { throw 'Gesture NAPI library is not AArch64.' }
$dependencies = @([regex]::Matches($dynamic, '\(NEEDED\).*\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$expected = @('libMNN.so', 'libace_napi.z.so', 'libc++_shared.so', 'libc.so') | Sort-Object
if (($dependencies -join '|') -cne ($expected -join '|')) {
  throw "Gesture NAPI DT_NEEDED mismatch: expected $($expected -join ', '), got $($dependencies -join ', ')"
}
if ($dynamic -notmatch '\((RUNPATH|RPATH)\).*\[\$ORIGIN\]') { throw 'Gesture NAPI library is missing $ORIGIN runpath.' }

Write-Output "Gesture native contract verified: $LibraryPath; DT_NEEDED=$($dependencies -join ',')"
