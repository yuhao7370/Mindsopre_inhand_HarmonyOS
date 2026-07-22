[CmdletBinding()]
param(
  [ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a',
  [string]$DevEcoSdkRoot = '',
  [string]$CacheRoot = '',
  [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceUrl = 'https://github.com/tukaani-project/xz/releases/download/v5.8.3/xz-5.8.3.tar.xz'
$sourceSha256 = 'FFF1FFCF2B0DA84D308A14DE513A1AA23D4E9AA3464D17E64B9714BFDD0BBFB6'
$tagCommit = '4b73f2ec19a99ef465282fbce633e8deb33691b3'
$requiredFlags = [ordered]@{
  BUILD_SHARED_LIBS = 'OFF'
  BUILD_TESTING = 'OFF'
  CMAKE_BUILD_TYPE = 'Release'
  CMAKE_POSITION_INDEPENDENT_CODE = 'ON'
  OHOS_ARCH = $Abi
  OHOS_PLATFORM_LEVEL = '24'
  XZ_ARM64_CRC32 = 'OFF'
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

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$translationRoot = Join-Path $projectRoot 'entry\src\main\cpp\translation_xz'
$xzRoot = Join-Path $translationRoot 'third_party\xz'
$lzmaPath = Join-Path $xzRoot "lib\$Abi\liblzma.a"
$wrapperPath = Join-Path $projectRoot "entry\libs\$Abi\libtranslation_archive.so"
$manifestName = if ($Abi -ceq 'arm64-v8a') { 'XZ_BUILD_MANIFEST.json' } else { "XZ_BUILD_MANIFEST.$Abi.json" }
$manifestPath = Join-Path $translationRoot $manifestName
$elfMachine = if ($Abi -ceq 'arm64-v8a') { 'AArch64' } else { 'Advanced Micro Devices X86-64' }
$target = if ($Abi -ceq 'arm64-v8a') { 'aarch64-linux-ohos' } else { 'x86_64-linux-ohos' }

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Label) {
  if ([string]$Actual -cne [string]$Expected) { throw "$Label mismatch: expected '$Expected', got '$Actual'" }
}

function Invoke-Captured([string]$Executable, [string[]]$Arguments) {
  $stderrPath = Join-Path $env:TEMP ("mindspore-inhand-xz-stderr-" + [guid]::NewGuid().ToString('N') + '.log')
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

function Resolve-NativeSdk([string]$RequestedRoot) {
  $candidates = @($RequestedRoot, $env:DEVECO_SDK_HOME,
    'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony',
    'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony')
  foreach ($candidate in $candidates) {
    if (-not $candidate) { continue }
    $root = [IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath (Join-Path $root 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) { return $root }
    $openharmony = Join-Path $root 'openharmony'
    if (Test-Path -LiteralPath (Join-Path $openharmony 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) {
      return [IO.Path]::GetFullPath($openharmony)
    }
  }
  throw 'HarmonyOS native SDK not found. Pass -DevEcoSdkRoot or set DEVECO_SDK_HOME.'
}

function Get-Toolchain([string]$NativeSdk) {
  $llvmBin = Join-Path $NativeSdk 'native\llvm\bin'
  $tools = [ordered]@{
    Clang = Join-Path $llvmBin 'clang.exe'
    ReadElf = Join-Path $llvmBin 'llvm-readelf.exe'
    Ar = Join-Path $llvmBin 'llvm-ar.exe'
    CMake = Join-Path $NativeSdk 'native\build-tools\cmake\bin\cmake.exe'
    Ninja = Join-Path $NativeSdk 'native\build-tools\cmake\bin\ninja.exe'
  }
  foreach ($tool in $tools.Values) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing DevEco tool: $tool" }
  }
  $clangVersion = Invoke-Captured $tools.Clang @('--version')
  if ($clangVersion -notmatch 'clang version 15\.0\.4' -or $clangVersion -notmatch '99548401bd80576251755b185ab95945e5fe7884') {
    throw "Unexpected OHOS Clang identity:`n$clangVersion"
  }
  $sdkPackagePath = [IO.Path]::GetFullPath((Join-Path $NativeSdk '..\sdk-pkg.json'))
  $sdk = Get-Content -LiteralPath $sdkPackagePath -Raw | ConvertFrom-Json
  Assert-Equal $sdk.data.platformVersion '6.1.1' 'DevEco SDK platform version'
  Assert-Equal $sdk.data.apiVersion 24 'DevEco SDK API level'
  return [pscustomobject]@{
    NativeSdk = $NativeSdk
    Clang = $tools.Clang
    ReadElf = $tools.ReadElf
    Ar = $tools.Ar
    CMake = $tools.CMake
    Ninja = $tools.Ninja
    CMakeVersion = (Invoke-Captured $tools.CMake @('--version')).Split("`n")[0].Trim()
    NinjaVersion = Invoke-Captured $tools.Ninja @('--version')
    SdkPackageVersion = [string]$sdk.data.version
  }
}

function Get-ElfEvidence([string]$Path, [string]$ReadElf, [switch]$Archive) {
  $arguments = if ($Archive) { @('-h', $Path) } else { @('-h', '-d', $Path) }
  $elf = Invoke-Captured $ReadElf $arguments
  $classes = @([regex]::Matches($elf, '(?m)^\s*Class:\s+(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  $machines = @([regex]::Matches($elf, '(?m)^\s*Machine:\s+(.+?)\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique)
  if (($classes -join '|') -cne 'ELF64') { throw "ELF class mismatch for $Path`: $($classes -join ', ')" }
  if (($machines -join '|') -cne $elfMachine) { throw "ELF machine mismatch for $Path`: $($machines -join ', ')" }
  $dependencies = if ($Archive) { @() } else {
    @([regex]::Matches($elf, '\(NEEDED\).*\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  }
  return [pscustomobject]@{ Class = 'ELF64'; Machine = $elfMachine; Dependencies = @($dependencies) }
}

function Assert-CMakeCache([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing CMake cache: $Path" }
  $values = @{}
  foreach ($line in [IO.File]::ReadLines($Path)) {
    if ($line -match '^([^#/][^:=]*)(?::[^=]+)?=(.*)$') { $values[$Matches[1]] = $Matches[2] }
  }
  foreach ($flag in $requiredFlags.GetEnumerator()) {
    if (-not $values.ContainsKey($flag.Key)) { throw "CMake cache is missing $($flag.Key)" }
    Assert-Equal $values[$flag.Key] $flag.Value "CMake $($flag.Key)"
  }
}

function Assert-Manifest([object]$Toolchain) {
  foreach ($path in @($manifestPath, $lzmaPath, $wrapperPath, (Join-Path $xzRoot 'COPYING'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing vendored XZ file: $path" }
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  Assert-Equal $manifest.schemaVersion 1 'Manifest schemaVersion'
  Assert-Equal $manifest.upstream.url $sourceUrl 'Manifest source URL'
  Assert-Equal $manifest.upstream.version '5.8.3' 'Manifest source version'
  Assert-Equal $manifest.upstream.tagCommit $tagCommit 'Manifest tag commit'
  Assert-Equal $manifest.upstream.sourceSha256 $sourceSha256 'Manifest source SHA-256'
  Assert-Equal $manifest.upstream.licenseFile 'COPYING' 'Manifest license file'
  Assert-Equal $manifest.toolchain.sdk '6.1.1' 'Manifest SDK'
  Assert-Equal $manifest.toolchain.sdkPackageVersion $Toolchain.SdkPackageVersion 'Manifest SDK package version'
  Assert-Equal $manifest.toolchain.apiLevel 24 'Manifest API level'
  Assert-Equal $manifest.toolchain.abi $Abi 'Manifest ABI'
  Assert-Equal $manifest.toolchain.target $target 'Manifest target'
  Assert-Equal $manifest.toolchain.clangVersion '15.0.4' 'Manifest Clang version'
  Assert-Equal $manifest.toolchain.llvmCommit '99548401bd80576251755b185ab95945e5fe7884' 'Manifest LLVM commit'
  Assert-Equal $manifest.toolchain.cmake $Toolchain.CMakeVersion 'Manifest CMake version'
  Assert-Equal $manifest.toolchain.ninja $Toolchain.NinjaVersion 'Manifest Ninja version'
  Assert-Equal $manifest.toolchain.jobs 1 'Manifest jobs'
  foreach ($flag in $requiredFlags.GetEnumerator()) {
    Assert-Equal $manifest.build.cmakeFlags.($flag.Key) $flag.Value "Manifest CMake $($flag.Key)"
  }
  Assert-Equal $manifest.build.target 'liblzma' 'Manifest build target'
  Assert-Equal $manifest.build.wrapperTarget 'translation_archive' 'Manifest wrapper target'

  $lzmaElf = Get-ElfEvidence $lzmaPath $Toolchain.ReadElf -Archive
  $wrapperElf = Get-ElfEvidence $wrapperPath $Toolchain.ReadElf
  $archiveMembers = Invoke-Captured $Toolchain.Ar @('t', $lzmaPath)
  if ($archiveMembers -notmatch 'stream_decoder' -or
      $archiveMembers -match '(?m)^(?:lz_encoder|lzma_encoder|lzma2_encoder)\.c\.o$') {
    throw 'liblzma archive is not the pinned decoder-only build.'
  }
  $expectedDependencies = @('libace_napi.z.so', 'libc++_shared.so', 'libc.so', 'libohcrypto.so') | Sort-Object
  if ((@($wrapperElf.Dependencies) -join '|') -cne ($expectedDependencies -join '|')) {
    throw "Translation wrapper DT_NEEDED mismatch: $(@($wrapperElf.Dependencies) -join ', ')"
  }
  $artifacts = @(
    [pscustomobject]@{ Value = $manifest.artifacts.liblzma; Path = $lzmaPath; Relative = "third_party/xz/lib/$Abi/liblzma.a"; Elf = $lzmaElf },
    [pscustomobject]@{ Value = $manifest.artifacts.napi; Path = $wrapperPath; Relative = "entry/libs/$Abi/libtranslation_archive.so"; Elf = $wrapperElf }
  )
  foreach ($artifact in $artifacts) {
    Assert-Equal $artifact.Value.path $artifact.Relative 'Manifest artifact path'
    Assert-Equal $artifact.Value.size (Get-Item -LiteralPath $artifact.Path).Length 'Manifest artifact size'
    Assert-Equal $artifact.Value.sha256 (Get-FileHash -LiteralPath $artifact.Path -Algorithm SHA256).Hash 'Manifest artifact SHA-256'
    Assert-Equal $artifact.Value.elfClass $artifact.Elf.Class 'Manifest artifact ELF class'
    Assert-Equal $artifact.Value.elfMachine $artifact.Elf.Machine 'Manifest artifact ELF machine'
    $manifestDependencies = @($artifact.Value.dynamicDependencies | Sort-Object)
    if (($manifestDependencies -join '|') -cne (@($artifact.Elf.Dependencies) -join '|')) {
      throw "Manifest dynamic dependencies mismatch: $($artifact.Relative)"
    }
  }
  $licensePath = Join-Path $xzRoot 'COPYING'
  Assert-Equal $manifest.license.path 'third_party/xz/COPYING' 'Manifest license path'
  Assert-Equal $manifest.license.sha256 (Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash 'Manifest license SHA-256'
  Write-Output "Pinned XZ HarmonyOS runtime verified for $Abi`: liblzma=$($manifest.artifacts.liblzma.sha256); wrapper=$($manifest.artifacts.napi.sha256)"
}

$nativeSdk = Resolve-NativeSdk $DevEcoSdkRoot
$toolchain = Get-Toolchain $nativeSdk
if ($VerifyOnly) {
  Assert-Manifest $toolchain
  exit 0
}

if (-not $CacheRoot) { $CacheRoot = Join-Path $env:LOCALAPPDATA 'MindsporeInhand\xz-ohos-5.8.3' }
$CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
[IO.Directory]::CreateDirectory($CacheRoot) | Out-Null
$archivePath = Join-Path $CacheRoot 'xz-5.8.3.tar.xz'
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
  $partialPath = "$archivePath.partial"
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $sourceUrl -OutFile $partialPath
    Assert-Equal (Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash $sourceSha256 'Downloaded XZ source SHA-256'
    Move-Item -LiteralPath $partialPath -Destination $archivePath
  } finally {
    if (Test-Path -LiteralPath $partialPath) { Remove-Item -LiteralPath $partialPath -Force }
  }
}
Assert-Equal (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash $sourceSha256 'XZ source SHA-256'

$runRoot = Join-Path $CacheRoot ('run.' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $runRoot 'source'
$buildRoot = Join-Path $runRoot "build-$Abi-api24"
$wrapperBuildRoot = Join-Path $runRoot "wrapper-$Abi-api24"
$cachePrefix = $CacheRoot.TrimEnd('\') + '\'
foreach ($path in @($runRoot, $sourceRoot, $buildRoot, $wrapperBuildRoot)) {
  if (-not ([IO.Path]::GetFullPath($path)).StartsWith($cachePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'XZ source/build paths escaped the script-owned cache.'
  }
}

try {
  [IO.Directory]::CreateDirectory($sourceRoot) | Out-Null
  Invoke-Captured 'tar.exe' @('-xf', $archivePath, '-C', $sourceRoot, '--strip-components=1') | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'CMakeLists.txt') -PathType Leaf)) { throw 'XZ source archive layout is invalid.' }
  Assert-Equal (Get-FileHash -LiteralPath (Join-Path $sourceRoot 'COPYING') -Algorithm SHA256).Hash '616A3AD264CE29B8F1CB97E53037B139D406899CA8D1F799651E17BFA09830B8' 'XZ license SHA-256'

  $cmakeArguments = @(
    '-S', $sourceRoot, '-B', $buildRoot, '-G', 'Ninja',
    "-DCMAKE_MAKE_PROGRAM=$($toolchain.Ninja)",
    "-DCMAKE_TOOLCHAIN_FILE=$(Join-Path $nativeSdk 'native\build\cmake\ohos.toolchain.cmake')"
  )
  foreach ($flag in $requiredFlags.GetEnumerator()) { $cmakeArguments += "-D$($flag.Key)=$($flag.Value)" }
  Invoke-Captured $toolchain.CMake $cmakeArguments | Out-Null
  Assert-CMakeCache (Join-Path $buildRoot 'CMakeCache.txt')
  Invoke-Captured $toolchain.CMake @('--build', $buildRoot, '--target', 'liblzma', '--parallel', '1') | Out-Null
  $builtLzma = Join-Path $buildRoot 'liblzma.a'
  if (-not (Test-Path -LiteralPath $builtLzma -PathType Leaf)) { throw "Missing built liblzma: $builtLzma" }
  Get-ElfEvidence $builtLzma $toolchain.ReadElf -Archive | Out-Null

  [IO.Directory]::CreateDirectory((Split-Path -Parent $lzmaPath)) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $xzRoot 'include\lzma')) | Out-Null
  [IO.Directory]::CreateDirectory((Split-Path -Parent $wrapperPath)) | Out-Null
  Copy-Item -LiteralPath $builtLzma -Destination $lzmaPath -Force
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'src\liblzma\api\lzma.h') -Destination (Join-Path $xzRoot 'include\lzma.h') -Force
  Copy-Item -Path (Join-Path $sourceRoot 'src\liblzma\api\lzma\*.h') -Destination (Join-Path $xzRoot 'include\lzma') -Force
  $licenseText = [IO.File]::ReadAllText((Join-Path $sourceRoot 'COPYING')).TrimEnd() + "`n"
  [IO.File]::WriteAllText((Join-Path $xzRoot 'COPYING'), $licenseText, [Text.UTF8Encoding]::new($false))

  $wrapperArguments = @(
    '-S', $translationRoot, '-B', $wrapperBuildRoot, '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_MAKE_PROGRAM=$($toolchain.Ninja)",
    "-DCMAKE_TOOLCHAIN_FILE=$(Join-Path $nativeSdk 'native\build\cmake\ohos.toolchain.cmake')",
    "-DOHOS_ARCH=$Abi", '-DOHOS_PLATFORM_LEVEL=24', '-DOHOS_STL=c++_shared'
  )
  Invoke-Captured $toolchain.CMake $wrapperArguments | Out-Null
  Invoke-Captured $toolchain.CMake @('--build', $wrapperBuildRoot, '--target', 'translation_archive', '--parallel', '1') | Out-Null
  $builtWrapper = Join-Path $wrapperBuildRoot 'libtranslation_archive.so'
  if (-not (Test-Path -LiteralPath $builtWrapper -PathType Leaf)) { throw "Missing built translation wrapper: $builtWrapper" }
  $lzmaElf = Get-ElfEvidence $lzmaPath $toolchain.ReadElf -Archive
  $wrapperElf = Get-ElfEvidence $builtWrapper $toolchain.ReadElf
  Copy-Item -LiteralPath $builtWrapper -Destination $wrapperPath -Force

  $flagManifest = [ordered]@{}
  foreach ($flag in $requiredFlags.GetEnumerator()) { $flagManifest[$flag.Key] = $flag.Value }
  $manifest = [ordered]@{
    schemaVersion = 1
    upstream = [ordered]@{ url = $sourceUrl; version = '5.8.3'; tagCommit = $tagCommit; sourceSha256 = $sourceSha256; licenseFile = 'COPYING' }
    toolchain = [ordered]@{
      sdk = '6.1.1'; sdkPackageVersion = $toolchain.SdkPackageVersion; apiLevel = 24; abi = $Abi; target = $target
      clangVersion = '15.0.4'; llvmCommit = '99548401bd80576251755b185ab95945e5fe7884'
      cmake = $toolchain.CMakeVersion; ninja = $toolchain.NinjaVersion; jobs = 1
    }
    build = [ordered]@{ cmakeFlags = $flagManifest; target = 'liblzma'; wrapperTarget = 'translation_archive' }
    artifacts = [ordered]@{
      liblzma = [ordered]@{
        path = "third_party/xz/lib/$Abi/liblzma.a"; size = (Get-Item $lzmaPath).Length
        sha256 = (Get-FileHash $lzmaPath -Algorithm SHA256).Hash; elfClass = $lzmaElf.Class; elfMachine = $lzmaElf.Machine
        dynamicDependencies = @($lzmaElf.Dependencies)
      }
      napi = [ordered]@{
        path = "entry/libs/$Abi/libtranslation_archive.so"; size = (Get-Item $wrapperPath).Length
        sha256 = (Get-FileHash $wrapperPath -Algorithm SHA256).Hash; elfClass = $wrapperElf.Class; elfMachine = $wrapperElf.Machine
        dynamicDependencies = @($wrapperElf.Dependencies)
      }
    }
    license = [ordered]@{ path = 'third_party/xz/COPYING'; sha256 = (Get-FileHash (Join-Path $xzRoot 'COPYING') -Algorithm SHA256).Hash }
  }
  [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
  Assert-Manifest $toolchain
} finally {
  if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
}
