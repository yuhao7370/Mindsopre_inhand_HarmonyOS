[CmdletBinding()]
param(
  [switch]$VerifyOnly,
  [switch]$UseExistingBuild,
  [string]$DevEcoSdkRoot = '',
  [string]$CacheRoot = '',
  [string]$SourceRoot = '',
  [string]$BuildRoot = '',
  [ValidateRange(1, 64)][int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$mnnRepository = 'https://github.com/alibaba/MNN.git'
$mnnCommit = '785907a83194f6607762742adab86240582aa013'
$referenceSize = 3409904
$referenceSha256 = 'A0D9F3BFBF5F97093438EA9E3D17AC8710F742228074A4E16C6196FE4AEC53A5'
$requiredHeaders = @(
  'ErrorCode.hpp',
  'HalideRuntime.h',
  'Interpreter.hpp',
  'MNNDefine.h',
  'MNNForwardType.h',
  'Tensor.hpp'
)
$requiredCMakeFlags = [ordered]@{
  CMAKE_BUILD_TYPE = 'Release'
  OHOS_ARCH = 'arm64-v8a'
  OHOS_PLATFORM_LEVEL = '24'
  OHOS_STL = 'c++_shared'
  MNN_BUILD_SHARED_LIBS = 'ON'
  MNN_SEP_BUILD = 'OFF'
  MNN_BUILD_TOOLS = 'OFF'
  MNN_BUILD_CONVERTER = 'OFF'
  MNN_BUILD_TRAIN = 'OFF'
  MNN_BUILD_TEST = 'OFF'
  MNN_BUILD_BENCHMARK = 'OFF'
  MNN_BUILD_OPENCV = 'OFF'
  MNN_BUILD_LLM = 'OFF'
  MNN_OPENCL = 'OFF'
  MNN_VULKAN = 'OFF'
  MNN_ARM82 = 'OFF'
  MNN_SUPPORT_BF16 = 'OFF'
  MNN_USE_LOGCAT = 'OFF'
  MNN_KLEIDIAI = 'OFF'
  MNN_BUILD_MINI = 'OFF'
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$libraryPath = Join-Path $projectRoot 'entry\libs\arm64-v8a\libMNN.so'
$includeRoot = Join-Path $projectRoot 'entry\src\main\cpp\include\MNN'
$thirdPartyRoot = Join-Path $projectRoot 'entry\src\main\cpp\third_party\MNN'
$licensePath = Join-Path $thirdPartyRoot 'LICENSE.txt'
$manifestPath = Join-Path $projectRoot 'entry\src\main\cpp\MNN_BUILD_MANIFEST.json'

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Label) {
  if ([string]$Actual -cne [string]$Expected) {
    throw "$Label mismatch: expected '$Expected', got '$Actual'"
  }
}

function Assert-ExactProperties([object]$Object, [string[]]$ExpectedNames, [string]$Label) {
  if ($null -eq $Object) { throw "$Label must be an object." }
  $properties = @($Object.PSObject.Properties)
  $actualNames = @($properties | ForEach-Object Name | Sort-Object)
  $expected = @($ExpectedNames | Sort-Object)
  if ($properties.Count -ne $expected.Count -or ($actualNames -join '|') -cne ($expected -join '|')) {
    throw "$Label properties mismatch: expected $($expected -join ', '), got $($actualNames -join ', ')"
  }
}

function Invoke-Captured([string]$Executable, [string[]]$Arguments) {
  $output = & $Executable @Arguments 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed ($LASTEXITCODE): $Executable $($Arguments -join ' ')`n$output"
  }
  return $output.Trim()
}

function Resolve-NativeSdk([string]$RequestedRoot) {
  $candidates = @()
  if ($RequestedRoot) { $candidates += $RequestedRoot }
  if ($env:DEVECO_SDK_HOME) { $candidates += $env:DEVECO_SDK_HOME }
  $candidates += 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony'

  foreach ($candidate in $candidates) {
    if (-not $candidate) { continue }
    $root = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath (Join-Path $root 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) {
      return $root
    }
    $openharmony = Join-Path $root 'openharmony'
    if (Test-Path -LiteralPath (Join-Path $openharmony 'native\llvm\bin\llvm-readelf.exe') -PathType Leaf) {
      return [System.IO.Path]::GetFullPath($openharmony)
    }
  }
  throw 'HarmonyOS native SDK not found. Pass -DevEcoSdkRoot or set DEVECO_SDK_HOME.'
}

function Read-CMakeCache([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing CMake cache: $Path"
  }
  $values = @{}
  foreach ($line in [System.IO.File]::ReadLines($Path)) {
    if ($line -match '^([^#/][^:=]*)(?::[^=]+)?=(.*)$') {
      $values[$Matches[1]] = $Matches[2]
    }
  }
  return $values
}

function Assert-CMakeContract([string]$Path) {
  $cache = Read-CMakeCache $Path
  foreach ($item in $requiredCMakeFlags.GetEnumerator()) {
    if (-not $cache.ContainsKey($item.Key)) {
      throw "CMake cache is missing $($item.Key)"
    }
    Assert-Equal $cache[$item.Key] $item.Value "CMake $($item.Key)"
  }
  Assert-Equal $cache['CMAKE_GENERATOR'] 'Ninja' 'CMake generator'
}

function Get-Toolchain([string]$NativeSdk) {
  $llvmBin = Join-Path $NativeSdk 'native\llvm\bin'
  $clang = Join-Path $llvmBin 'clang.exe'
  $readelf = Join-Path $llvmBin 'llvm-readelf.exe'
  $cmake = Join-Path $NativeSdk 'native\build-tools\cmake\bin\cmake.exe'
  $ninja = Join-Path $NativeSdk 'native\build-tools\cmake\bin\ninja.exe'
  foreach ($tool in @($clang, $readelf, $cmake, $ninja)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing DevEco tool: $tool" }
  }

  $clangVersion = Invoke-Captured $clang @('--version')
  if ($clangVersion -notmatch 'clang version 15\.0\.4' -or
      $clangVersion -notmatch '99548401bd80576251755b185ab95945e5fe7884') {
    throw "Unexpected OHOS Clang identity:`n$clangVersion"
  }

  $sdkPackage = [System.IO.Path]::GetFullPath((Join-Path $NativeSdk '..\sdk-pkg.json'))
  if (-not (Test-Path -LiteralPath $sdkPackage -PathType Leaf)) {
    throw "Missing SDK package metadata: $sdkPackage"
  }
  $sdk = Get-Content -LiteralPath $sdkPackage -Raw | ConvertFrom-Json
  Assert-Equal $sdk.data.platformVersion '6.1.1' 'DevEco SDK platform version'
  Assert-Equal $sdk.data.apiVersion '24' 'DevEco SDK API level'

  return [pscustomobject]@{
    NativeSdk = $NativeSdk
    Clang = $clang
    ReadElf = $readelf
    CMake = $cmake
    Ninja = $ninja
    CMakeVersion = (Invoke-Captured $cmake @('--version')).Split("`n")[0].Trim()
    NinjaVersion = Invoke-Captured $ninja @('--version')
    SdkPackageVersion = [string]$sdk.data.version
  }
}

function Get-ElfContract([string]$Path, [string]$ReadElf) {
  $elf = Invoke-Captured $ReadElf @('-h', '-d', $Path)
  if ($elf -notmatch '(?m)^\s*Class:\s+ELF64\s*$') { throw "MNN runtime is not ELF64: $Path" }
  if ($elf -notmatch '(?m)^\s*Machine:\s+AArch64\s*$') { throw "MNN runtime is not AArch64: $Path" }
  $dependencies = @([regex]::Matches($elf, '\(NEEDED\).*\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  $expected = @('libc++_shared.so', 'libc.so') | Sort-Object
  if (($dependencies -join '|') -cne ($expected -join '|')) {
    throw "MNN DT_NEEDED mismatch: expected $($expected -join ', '), got $($dependencies -join ', ')"
  }
  return $dependencies
}

function Assert-VendoredRuntime([object]$Toolchain) {
  foreach ($path in @($libraryPath, $manifestPath, $licensePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing vendored MNN file: $path" }
  }
  $manifestJson = Get-Content -LiteralPath $manifestPath -Raw
  $manifest = $manifestJson | ConvertFrom-Json
  Assert-Equal $manifest.schemaVersion 1 'Manifest schemaVersion'
  Assert-Equal $manifest.upstream.repository $mnnRepository 'MNN repository'
  Assert-Equal $manifest.upstream.commit $mnnCommit 'MNN commit'
  Assert-Equal $manifest.upstream.configureVersion '3.6.0' 'MNN configure version'
  Assert-Equal $manifest.upstream.license 'Apache-2.0' 'MNN license'
  Assert-Equal $manifest.toolchain.devEcoSdk '6.1.1' 'Manifest DevEco SDK'
  Assert-Equal $manifest.toolchain.sdkPackageVersion $Toolchain.SdkPackageVersion 'Manifest SDK package version'
  Assert-Equal $manifest.toolchain.apiLevel 24 'Manifest API level'
  Assert-Equal $manifest.toolchain.clangVersion '15.0.4' 'Manifest Clang version'
  Assert-Equal $manifest.toolchain.llvmCommit '99548401bd80576251755b185ab95945e5fe7884' 'Manifest LLVM commit'
  Assert-Equal $manifest.toolchain.target 'aarch64-linux-ohos' 'Manifest target'
  Assert-Equal $manifest.toolchain.abi 'arm64-v8a' 'Manifest ABI'
  Assert-Equal $manifest.toolchain.stl 'c++_shared' 'Manifest STL'
  Assert-Equal $manifest.toolchain.cmake $Toolchain.CMakeVersion 'Manifest CMake version'
  Assert-Equal $manifest.toolchain.ninja $Toolchain.NinjaVersion 'Manifest Ninja version'
  Assert-Equal $manifest.build.generator 'Ninja' 'Manifest build generator'
  Assert-Equal $manifest.build.target 'MNN' 'Manifest build target'
  $expectedFlagNames = @($requiredCMakeFlags.Keys)
  Assert-ExactProperties $manifest.build.cmakeFlags $expectedFlagNames 'Manifest CMake flags'
  $rawFlagBlocks = [regex]::Matches($manifestJson, '"cmakeFlags"\s*:\s*\{(?<body>[^{}]*)\}')
  if ($rawFlagBlocks.Count -ne 1) { throw 'Manifest must contain exactly one flat cmakeFlags object.' }
  $rawFlagNames = @([regex]::Matches($rawFlagBlocks[0].Groups['body'].Value, '"(?<name>[A-Za-z0-9_]+)"\s*:') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object)
  if ($rawFlagNames.Count -ne $expectedFlagNames.Count -or
      ($rawFlagNames -join '|') -cne (($expectedFlagNames | Sort-Object) -join '|')) {
    throw "Manifest raw CMake flag names mismatch: $($rawFlagNames -join ', ')"
  }
  foreach ($item in $requiredCMakeFlags.GetEnumerator()) {
    $value = $manifest.build.cmakeFlags.($item.Key)
    if ($value -isnot [string]) { throw "Manifest CMake $($item.Key) must be a string." }
    Assert-Equal $value $item.Value "Manifest CMake $($item.Key)"
  }

  $actualHash = (Get-FileHash -LiteralPath $libraryPath -Algorithm SHA256).Hash
  $actualSize = (Get-Item -LiteralPath $libraryPath).Length
  Assert-Equal $manifest.artifact.path 'entry/libs/arm64-v8a/libMNN.so' 'Manifest artifact path'
  Assert-Equal $manifest.artifact.elfClass 'ELF64' 'Manifest ELF class'
  Assert-Equal $manifest.artifact.elfMachine 'AArch64' 'Manifest ELF machine'
  Assert-Equal $manifest.reference.sha256 $referenceSha256 'Manifest reference SHA-256'
  Assert-Equal $manifest.reference.size $referenceSize 'Manifest reference size'
  Assert-Equal $actualHash $referenceSha256 'Vendored artifact SHA-256'
  Assert-Equal $actualSize $referenceSize 'Vendored artifact size'
  Assert-Equal $manifest.artifact.sha256 $referenceSha256 'Manifest artifact SHA-256'
  Assert-Equal $manifest.artifact.size $referenceSize 'Manifest artifact size'
  if ($null -ne $manifest.toolchainInputDifference) {
    throw 'Manifest toolchainInputDifference must be null for the fixed reference artifact.'
  }
  $dependencies = Get-ElfContract $libraryPath $Toolchain.ReadElf
  if ((@($manifest.artifact.dynamicDependencies | Sort-Object) -join '|') -cne ($dependencies -join '|')) {
    throw 'Manifest dynamicDependencies do not match the ELF.'
  }

  $actualHeaders = @(Get-ChildItem -LiteralPath $includeRoot -Recurse -File | ForEach-Object {
    $_.FullName.Substring($includeRoot.Length + 1).Replace('\', '/')
  } | Sort-Object)
  if (($actualHeaders -join '|') -cne (($requiredHeaders | Sort-Object) -join '|')) {
    throw "Vendored public header set is not minimal: $($actualHeaders -join ', ')"
  }
  if ($manifest.headers -isnot [System.Array]) { throw 'Manifest headers must be an array.' }
  $manifestHeaders = @($manifest.headers)
  $expectedHeaderPaths = @($requiredHeaders | ForEach-Object { "include/MNN/$_" } | Sort-Object)
  $manifestHeaderPaths = @($manifestHeaders | ForEach-Object { $_.path } | Sort-Object)
  if ($manifestHeaders.Count -ne $expectedHeaderPaths.Count -or
      ($manifestHeaderPaths -join '|') -cne ($expectedHeaderPaths -join '|')) {
    throw "Manifest header paths mismatch: expected $($expectedHeaderPaths -join ', '), got $($manifestHeaderPaths -join ', ')"
  }
  foreach ($entry in $manifestHeaders) {
    Assert-ExactProperties $entry @('path', 'sha256') "Manifest header entry '$($entry.path)'"
    if ($entry.path -isnot [string] -or $entry.sha256 -isnot [string]) {
      throw 'Manifest header path and sha256 must be strings.'
    }
    if ($entry.sha256 -cnotmatch '^[0-9A-F]{64}$') { throw "Invalid header SHA-256 for $($entry.path)" }
  }
  foreach ($header in $requiredHeaders) {
    $entry = @($manifest.headers | Where-Object { $_.path -ceq "include/MNN/$header" })
    if ($entry.Count -ne 1) { throw "Manifest must contain exactly one entry for header $header" }
    $hash = (Get-FileHash -LiteralPath (Join-Path $includeRoot $header) -Algorithm SHA256).Hash
    Assert-Equal $hash $entry[0].sha256 "Header $header SHA-256"
  }
  $licenseHash = (Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash
  Assert-Equal $manifest.license.path 'third_party/MNN/LICENSE.txt' 'License path'
  Assert-Equal $manifest.license.sha256 $licenseHash 'License SHA-256'
  Write-Output "Pinned MNN HarmonyOS runtime verified: $actualHash; DT_NEEDED=$($dependencies -join ',')"
}

$nativeSdk = Resolve-NativeSdk $DevEcoSdkRoot
$toolchain = Get-Toolchain $nativeSdk
if ($VerifyOnly) {
  Assert-VendoredRuntime $toolchain
  exit 0
}

if (-not $CacheRoot) {
  $CacheRoot = Join-Path $env:LOCALAPPDATA "MindsporeInhand\mnn-ohos-$mnnCommit"
}
$CacheRoot = [System.IO.Path]::GetFullPath($CacheRoot)
if (-not $SourceRoot) { $SourceRoot = Join-Path $CacheRoot 'source' }
if (-not $BuildRoot) { $BuildRoot = Join-Path $CacheRoot 'build-arm64-v8a-api24' }
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$BuildRoot = [System.IO.Path]::GetFullPath($BuildRoot)

if (-not $UseExistingBuild) {
  $cachePrefix = $CacheRoot.TrimEnd('\') + '\'
  if (-not $SourceRoot.StartsWith($cachePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
      -not $BuildRoot.StartsWith($cachePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot and BuildRoot must stay inside the script-owned CacheRoot unless -UseExistingBuild is set.'
  }
  [System.IO.Directory]::CreateDirectory($CacheRoot) | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot '.git') -PathType Container)) {
    if (Test-Path -LiteralPath $SourceRoot) { throw "Refusing to replace non-git source path: $SourceRoot" }
    Invoke-Captured 'git' @('clone', '--filter=blob:none', '--no-checkout', $mnnRepository, $SourceRoot) | Out-Null
  }
  Invoke-Captured 'git' @('-C', $SourceRoot, 'fetch', '--depth', '1', 'origin', $mnnCommit) | Out-Null
  Invoke-Captured 'git' @('-C', $SourceRoot, 'checkout', '--detach', '--force', $mnnCommit) | Out-Null
}

if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot '.git') -PathType Container)) {
  throw "MNN source is not a git checkout: $SourceRoot"
}
$sourceCommit = Invoke-Captured 'git' @('-C', $SourceRoot, 'rev-parse', 'HEAD')
Assert-Equal $sourceCommit $mnnCommit 'MNN source HEAD'
$sourceStatus = Invoke-Captured 'git' @('-C', $SourceRoot, 'status', '--porcelain', '--untracked-files=no')
if ($sourceStatus) { throw "MNN source has tracked changes:`n$sourceStatus" }

if (-not $UseExistingBuild) {
  [System.IO.Directory]::CreateDirectory($BuildRoot) | Out-Null
  $cmakeArguments = @(
    '-S', $SourceRoot, '-B', $BuildRoot, '-G', 'Ninja',
    "-DCMAKE_MAKE_PROGRAM=$($toolchain.Ninja)",
    "-DCMAKE_TOOLCHAIN_FILE=$(Join-Path $nativeSdk 'native\build\cmake\ohos.toolchain.cmake')"
  )
  foreach ($item in $requiredCMakeFlags.GetEnumerator()) {
    $cmakeArguments += "-D$($item.Key)=$($item.Value)"
  }
  Invoke-Captured $toolchain.CMake $cmakeArguments | Out-Null
  Assert-CMakeContract (Join-Path $BuildRoot 'CMakeCache.txt')
  Invoke-Captured $toolchain.CMake @('--build', $BuildRoot, '--target', 'MNN', '--parallel', [string]$Jobs) | Out-Null
}

Assert-CMakeContract (Join-Path $BuildRoot 'CMakeCache.txt')
$builtLibrary = Join-Path $BuildRoot 'libMNN.so'
if (-not (Test-Path -LiteralPath $builtLibrary -PathType Leaf)) { throw "Missing built MNN runtime: $builtLibrary" }
$dependencies = Get-ElfContract $builtLibrary $toolchain.ReadElf
$builtHash = (Get-FileHash -LiteralPath $builtLibrary -Algorithm SHA256).Hash
$builtSize = (Get-Item -LiteralPath $builtLibrary).Length
Assert-Equal $builtHash $referenceSha256 'Built MNN SHA-256'
Assert-Equal $builtSize $referenceSize 'Built MNN size'

$sourceIncludeRoot = Join-Path $SourceRoot 'include\MNN'
foreach ($header in $requiredHeaders) {
  if (-not (Test-Path -LiteralPath (Join-Path $sourceIncludeRoot $header) -PathType Leaf)) {
    throw "Pinned source is missing required public header: $header"
  }
}
$sourceLicense = Join-Path $SourceRoot 'LICENSE.txt'
if (-not (Test-Path -LiteralPath $sourceLicense -PathType Leaf)) { throw "Pinned source is missing LICENSE.txt" }

[System.IO.Directory]::CreateDirectory((Split-Path -Parent $libraryPath)) | Out-Null
[System.IO.Directory]::CreateDirectory($includeRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($thirdPartyRoot) | Out-Null
Copy-Item -LiteralPath $builtLibrary -Destination $libraryPath -Force
foreach ($header in $requiredHeaders) {
  Copy-Item -LiteralPath (Join-Path $sourceIncludeRoot $header) -Destination (Join-Path $includeRoot $header) -Force
}
Copy-Item -LiteralPath $sourceLicense -Destination $licensePath -Force

$headerManifest = @($requiredHeaders | ForEach-Object {
  $path = Join-Path $includeRoot $_
  [ordered]@{ path = "include/MNN/$_"; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
})
$flagManifest = [ordered]@{}
foreach ($item in $requiredCMakeFlags.GetEnumerator()) { $flagManifest[$item.Key] = $item.Value }
$manifest = [ordered]@{
  schemaVersion = 1
  upstream = [ordered]@{
    repository = $mnnRepository
    commit = $mnnCommit
    configureVersion = '3.6.0'
    license = 'Apache-2.0'
  }
  toolchain = [ordered]@{
    devEcoSdk = '6.1.1'
    sdkPackageVersion = $toolchain.SdkPackageVersion
    apiLevel = 24
    clangVersion = '15.0.4'
    llvmCommit = '99548401bd80576251755b185ab95945e5fe7884'
    target = 'aarch64-linux-ohos'
    abi = 'arm64-v8a'
    stl = 'c++_shared'
    cmake = $toolchain.CMakeVersion
    ninja = $toolchain.NinjaVersion
  }
  build = [ordered]@{ generator = 'Ninja'; target = 'MNN'; cmakeFlags = $flagManifest }
  artifact = [ordered]@{
    path = 'entry/libs/arm64-v8a/libMNN.so'
    size = $builtSize
    sha256 = $builtHash
    elfClass = 'ELF64'
    elfMachine = 'AArch64'
    dynamicDependencies = @($dependencies)
  }
  reference = [ordered]@{ size = $referenceSize; sha256 = $referenceSha256 }
  headers = $headerManifest
  license = [ordered]@{
    path = 'third_party/MNN/LICENSE.txt'
    sha256 = (Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash
  }
  toolchainInputDifference = $null
}
[System.IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + "`n"), [System.Text.UTF8Encoding]::new($false))
Assert-VendoredRuntime $toolchain
