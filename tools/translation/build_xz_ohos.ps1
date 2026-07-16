[CmdletBinding()]
param(
  [switch]$VerifyOnly,
  [ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a',
  [string]$DevEcoSdkRoot = '',
  [string]$CacheRoot = '',
  [string]$SourceArchive = '',
  [ValidateRange(1, 8)][int]$Jobs = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$xzVersion = '5.8.3'
$xzTagCommit = '4b73f2ec19a99ef465282fbce633e8deb33691b3'
$xzUrl = 'https://github.com/tukaani-project/xz/releases/download/v5.8.3/xz-5.8.3.tar.xz'
$xzSourceSha256 = 'FFF1FFCF2B0DA84D308A14DE513A1AA23D4E9AA3464D17E64B9714BFDD0BBFB6'
$requiredFlags = [ordered]@{
  BUILD_SHARED_LIBS = 'OFF'
  BUILD_TESTING = 'OFF'
  CMAKE_BUILD_TYPE = 'Release'
  CMAKE_POSITION_INDEPENDENT_CODE = 'ON'
  OHOS_ARCH = $Abi
  OHOS_PLATFORM_LEVEL = '24'
  XZ_ARM64_CRC32 = 'OFF'
  # XZ streams use LZMA2, whose implementation reuses the LZMA1 range decoder.
  XZ_DECODERS = 'lzma1;lzma2'
  XZ_DOC = 'OFF'
  XZ_ENCODERS = ''
  XZ_LZIP_DECODER = 'OFF'
  XZ_MICROLZMA_DECODER = 'OFF'
  XZ_MICROLZMA_ENCODER = 'OFF'
  XZ_NLS = 'OFF'
  XZ_SMALL = 'ON'
  XZ_THREADS = 'no'
  XZ_TOOL_LZMADEC = 'OFF'
  XZ_TOOL_LZMAINFO = 'OFF'
  XZ_TOOL_SCRIPTS = 'OFF'
  XZ_TOOL_XZ = 'OFF'
  XZ_TOOL_XZDEC = 'OFF'
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$projectRoot = Join-Path $repositoryRoot 'Mindspore_inhand_HarmonyOS'
$nativeRoot = Join-Path $projectRoot 'entry\src\main\cpp\translation_xz'
$importRoot = Join-Path $nativeRoot 'third_party\xz'
$libraryImport = Join-Path $importRoot "lib\$Abi\liblzma.a"
$includeImport = Join-Path $importRoot 'include'
$licenseImport = Join-Path $importRoot 'COPYING'
$sharedImport = Join-Path $projectRoot "entry\libs\$Abi\libtranslation_archive.so"
$manifestName = if ($Abi -ceq 'arm64-v8a') { 'XZ_BUILD_MANIFEST.json' } else { "XZ_BUILD_MANIFEST.$Abi.json" }
$manifestPath = Join-Path $nativeRoot $manifestName

function Invoke-Captured([string]$Executable, [string[]]$Arguments) {
  $stderrPath = Join-Path $env:TEMP ("mindspore-inhand-native-stderr-" + [guid]::NewGuid().ToString('N') + '.log')
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'SilentlyContinue'
    $stdout = & $Executable @Arguments 2> $stderrPath | Out-String
    $exitCode = $LASTEXITCODE
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
    $output = ($stdout + $stderr).Trim()
  } finally {
    $ErrorActionPreference = $previousPreference
    if (Test-Path -LiteralPath $stderrPath) { Remove-Item -LiteralPath $stderrPath -Force }
  }
  if ($exitCode -ne 0) { throw "Command failed ($exitCode): $Executable $($Arguments -join ' ')`n$output" }
  return $output
}

function Resolve-NativeSdk([string]$Requested) {
  foreach ($candidate in @(
    $Requested,
    $env:DEVECO_SDK_HOME,
    'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony',
    'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony'
  )) {
    if (-not $candidate) { continue }
    $root = [IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath (Join-Path $root 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $root }
    $nested = Join-Path $root 'openharmony'
    if (Test-Path -LiteralPath (Join-Path $nested 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $nested }
  }
  throw 'HarmonyOS native SDK not found.'
}

function Resolve-Tools([string]$Sdk) {
  $result = [pscustomobject]@{
    CMake = Join-Path $Sdk 'native\build-tools\cmake\bin\cmake.exe'
    Ninja = Join-Path $Sdk 'native\build-tools\cmake\bin\ninja.exe'
    ReadElf = Join-Path $Sdk 'native\llvm\bin\llvm-readelf.exe'
    Ar = Join-Path $Sdk 'native\llvm\bin\llvm-ar.exe'
    Toolchain = Join-Path $Sdk 'native\build\cmake\ohos.toolchain.cmake'
  }
  foreach ($property in $result.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath $property.Value -PathType Leaf)) { throw "Missing DevEco tool: $($property.Value)" }
  }
  return $result
}

function Read-Cache([string]$Path) {
  $values = @{}
  foreach ($line in [IO.File]::ReadLines($Path)) {
    if ($line -match '^([^#/][^:=]*)(?::[^=]+)?=(.*)$') { $values[$Matches[1]] = $Matches[2] }
  }
  return $values
}

function Assert-BuildCache([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing XZ CMake cache: $Path" }
  $cache = Read-Cache $Path
  foreach ($entry in $requiredFlags.GetEnumerator()) {
    if (-not $cache.ContainsKey($entry.Key) -or [string]$cache[$entry.Key] -cne [string]$entry.Value) {
      throw "XZ CMake flag $($entry.Key) mismatch."
    }
  }
}

function Get-Dependencies([string]$Path, [string]$ReadElf) {
  $elf = Invoke-Captured $ReadElf @('-h', '-d', $Path)
  $machine = if ($Abi -ceq 'arm64-v8a') { 'AArch64' } else { 'Advanced Micro Devices X86-64' }
  if ($elf -notmatch '(?m)^\s*Class:\s+ELF64\s*$' -or $elf -notmatch ("(?m)^\s*Machine:\s+" + [regex]::Escape($machine) + '\s*$')) {
    throw "Translation archive library must be an $machine ELF64 artifact."
  }
  return @([regex]::Matches($elf, '\(NEEDED\).*\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

function Assert-Imported([object]$Tools) {
  foreach ($path in @($libraryImport, $licenseImport, $sharedImport, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing pinned XZ import: $path" }
  }
  $headers = @(Get-ChildItem -LiteralPath $includeImport -Recurse -File | Sort-Object FullName)
  if ($headers.Count -lt 10) { throw 'Pinned liblzma public headers are incomplete.' }
  $archiveMembers = Invoke-Captured $Tools.Ar @('t', $libraryImport)
  if (-not $archiveMembers -or $archiveMembers -notmatch 'stream_decoder') { throw 'Imported liblzma archive lacks decoder objects.' }
  # lzma_encoder_presets.c is shared decoder support upstream; reject actual
  # LZ/LZMA encoder implementations while allowing that one helper object.
  if ($archiveMembers -match '(?m)^(?:lz_encoder|lzma_encoder|lzma2_encoder)\.c\.o$') {
    throw 'Imported liblzma unexpectedly contains encoder implementation objects.'
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1 -or $manifest.upstream.version -cne $xzVersion -or
      $manifest.upstream.tagCommit -cne $xzTagCommit -or $manifest.upstream.sourceSha256 -cne $xzSourceSha256) {
    throw 'XZ build manifest upstream identity mismatch.'
  }
  if ($manifest.toolchain.abi -cne $Abi) { throw "XZ build manifest ABI mismatch: $($manifest.toolchain.abi)" }
  foreach ($entry in $requiredFlags.GetEnumerator()) {
    if ([string]$manifest.build.cmakeFlags.($entry.Key) -cne [string]$entry.Value) {
      throw "XZ manifest flag $($entry.Key) mismatch."
    }
  }
  if ((Get-FileHash -LiteralPath $libraryImport -Algorithm SHA256).Hash -cne $manifest.artifacts.liblzma.sha256 -or
      (Get-Item -LiteralPath $libraryImport).Length -ne $manifest.artifacts.liblzma.size -or
      (Get-FileHash -LiteralPath $sharedImport -Algorithm SHA256).Hash -cne $manifest.artifacts.napi.sha256 -or
      (Get-Item -LiteralPath $sharedImport).Length -ne $manifest.artifacts.napi.size) {
    throw 'XZ imported artifact size/hash mismatch.'
  }
  $dependencies = Get-Dependencies $sharedImport $Tools.ReadElf
  $expected = @('libace_napi.z.so', 'libc++_shared.so', 'libc.so', 'libohcrypto.so') | Sort-Object
  if (($dependencies -join '|') -cne ($expected -join '|')) {
    throw "Translation archive DT_NEEDED mismatch: $($dependencies -join ', ')"
  }
  Write-Output "Pinned XZ $xzVersion OHOS extractor verified: $($manifest.artifacts.napi.sha256)"
}

$sdk = Resolve-NativeSdk $DevEcoSdkRoot
$tools = Resolve-Tools $sdk
if ($VerifyOnly) {
  Assert-Imported $tools
  exit 0
}

if (-not $CacheRoot) { $CacheRoot = Join-Path $env:LOCALAPPDATA "MindsporeInhand\xz-ohos-$xzVersion" }
$CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
[IO.Directory]::CreateDirectory($CacheRoot) | Out-Null

if (-not $SourceArchive) {
  $SourceArchive = Join-Path $CacheRoot "xz-$xzVersion.tar.xz"
  if (-not (Test-Path -LiteralPath $SourceArchive -PathType Leaf)) {
    $download = "$SourceArchive.partial"
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $xzUrl -OutFile $download
      if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -cne $xzSourceSha256) {
        throw 'Downloaded XZ source SHA-256 mismatch.'
      }
      Move-Item -LiteralPath $download -Destination $SourceArchive
    } finally {
      if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
    }
  }
}
$SourceArchive = [IO.Path]::GetFullPath($SourceArchive)
if ((Get-FileHash -LiteralPath $SourceArchive -Algorithm SHA256).Hash -cne $xzSourceSha256) {
  throw "XZ source SHA-256 mismatch: $SourceArchive"
}

$runRoot = Join-Path $CacheRoot ('run.' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $runRoot 'source'
$buildRoot = Join-Path $runRoot "build-$Abi-api24"
$wrapperBuild = Join-Path $runRoot "wrapper-$Abi-api24"
$cachePrefix = $CacheRoot.TrimEnd('\') + '\'
foreach ($path in @($runRoot, $sourceRoot, $buildRoot, $wrapperBuild)) {
  if (-not ([IO.Path]::GetFullPath($path)).StartsWith($cachePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'XZ source/build paths escaped the script-owned cache.'
  }
}

try {
  [IO.Directory]::CreateDirectory($sourceRoot) | Out-Null
  Push-Location $sourceRoot
  try {
    Invoke-Captured 'tar.exe' @('-xJf', $SourceArchive, '--strip-components=1') | Out-Null
  } finally {
    Pop-Location
  }
$versionHeader = Get-Content -LiteralPath (Join-Path $sourceRoot 'src\liblzma\api\lzma\version.h') -Raw
if ($versionHeader -notmatch '#define LZMA_VERSION_MAJOR 5' -or
    $versionHeader -notmatch '#define LZMA_VERSION_MINOR 8' -or
    $versionHeader -notmatch '#define LZMA_VERSION_PATCH 3') {
  throw 'Extracted XZ source version differs from 5.8.3.'
}

[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
$configure = @(
  '-S', $sourceRoot, '-B', $buildRoot, '-G', 'Ninja',
  "-DCMAKE_MAKE_PROGRAM=$($tools.Ninja)", "-DCMAKE_TOOLCHAIN_FILE=$($tools.Toolchain)"
)
foreach ($entry in $requiredFlags.GetEnumerator()) { $configure += "-D$($entry.Key)=$($entry.Value)" }
Invoke-Captured $tools.CMake $configure | Out-Null
Assert-BuildCache (Join-Path $buildRoot 'CMakeCache.txt')
Invoke-Captured $tools.CMake @('--build', $buildRoot, '--target', 'liblzma', '--parallel', [string]$Jobs) | Out-Null
$builtStatic = Join-Path $buildRoot 'liblzma.a'
if (-not (Test-Path -LiteralPath $builtStatic -PathType Leaf)) { throw "Missing built liblzma: $builtStatic" }

[IO.Directory]::CreateDirectory((Split-Path -Parent $libraryImport)) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $includeImport 'lzma')) | Out-Null
Copy-Item -LiteralPath $builtStatic -Destination $libraryImport -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'src\liblzma\api\lzma.h') -Destination $includeImport -Force
Copy-Item -Path (Join-Path $sourceRoot 'src\liblzma\api\lzma\*.h') -Destination (Join-Path $includeImport 'lzma') -Force
$licenseText = [IO.File]::ReadAllText((Join-Path $sourceRoot 'COPYING')).TrimEnd() + "`n"
[IO.File]::WriteAllText($licenseImport, $licenseText, [Text.UTF8Encoding]::new($false))

[IO.Directory]::CreateDirectory($wrapperBuild) | Out-Null
Invoke-Captured $tools.CMake @(
  '-S', $nativeRoot, '-B', $wrapperBuild, '-G', 'Ninja',
  "-DCMAKE_MAKE_PROGRAM=$($tools.Ninja)", "-DCMAKE_TOOLCHAIN_FILE=$($tools.Toolchain)",
  '-DCMAKE_BUILD_TYPE=Release', "-DOHOS_ARCH=$Abi", '-DOHOS_PLATFORM_LEVEL=24',
  "-DXZ_IMPORTED_ROOT=$importRoot"
) | Out-Null
Invoke-Captured $tools.CMake @('--build', $wrapperBuild, '--target', 'translation_archive', '--parallel', [string]$Jobs) | Out-Null
$builtShared = Join-Path $wrapperBuild 'libtranslation_archive.so'
if (-not (Test-Path -LiteralPath $builtShared -PathType Leaf)) { throw "Missing built extractor: $builtShared" }
[IO.Directory]::CreateDirectory((Split-Path -Parent $sharedImport)) | Out-Null
Copy-Item -LiteralPath $builtShared -Destination $sharedImport -Force

$flagManifest = [ordered]@{}
foreach ($entry in $requiredFlags.GetEnumerator()) { $flagManifest[$entry.Key] = $entry.Value }
$manifest = [ordered]@{
  schemaVersion = 1
  upstream = [ordered]@{
    url = $xzUrl
    version = $xzVersion
    tagCommit = $xzTagCommit
    sourceSha256 = $xzSourceSha256
    licenseFile = 'COPYING'
  }
  toolchain = [ordered]@{ sdk = '6.1.1'; apiLevel = 24; abi = $Abi; jobs = $Jobs }
  build = [ordered]@{ cmakeFlags = $flagManifest; target = 'liblzma'; wrapperTarget = 'translation_archive' }
  artifacts = [ordered]@{
    liblzma = [ordered]@{ path = "third_party/xz/lib/$Abi/liblzma.a"; size = (Get-Item $libraryImport).Length; sha256 = (Get-FileHash $libraryImport -Algorithm SHA256).Hash }
    napi = [ordered]@{ path = "entry/libs/$Abi/libtranslation_archive.so"; size = (Get-Item $sharedImport).Length; sha256 = (Get-FileHash $sharedImport -Algorithm SHA256).Hash }
  }
}
[IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
Assert-Imported $tools
} finally {
  if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
}
