$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$pagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = Get-Content -Raw -Encoding UTF8 -LiteralPath $pagePath

$forbiddenPatterns = @(
  'Text\s*\(\s*this\.(aiMethod|selectedInputSummary)\s*\)',
  'this\.resultText\s*=\s*this\.aiMethod',
  'this\.resultText\s*=\s*result\.detailText\.length\s*>\s*0\s*\?\s*result\.detailText\s*:\s*`\$\{result\.aiMethod\}'
)

$matches = @($forbiddenPatterns | Where-Object { $source -match $_ })
if ($matches.Count -gt 0) {
  throw "FeatureRuntimePage renders internal debug fields: $($matches -join ', ')"
}

$resourcePaths = @(
  'entry/src/main/resources/base/element/string.json',
  'entry/src/main/resources/en_US/element/string.json',
  'entry/src/main/resources/zh_CN/element/string.json'
)

function Decode-Utf8Base64([string] $encoded) {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
}

$forbiddenResourceValuePatterns = @(
  'HarmonyOS shell',
  '\brunner\b',
  ([regex]::Escape((Decode-Utf8Base64 '5a+55o6l5Y6fIEFuZHJvaWQ='))),
  ([regex]::Escape((Decode-Utf8Base64 '5Y6fIEFuZHJvaWQgTWluZFNwb3Jl'))),
  ([regex]::Escape((Decode-Utf8Base64 '5Y6f5aeLIE1pbmRTcG9yZQ=='))),
  'original MindSpore',
  'NATIVE_ADAPTER_PENDING',
  'service migration',
  '\bqueued\b'
)

$resourceMatches = @()
foreach ($relativePath in $resourcePaths) {
  $resourcePath = Join-Path $root $relativePath
  $resource = Get-Content -Raw -Encoding UTF8 -LiteralPath $resourcePath | ConvertFrom-Json
  foreach ($entry in $resource.string) {
    $value = [string]$entry.value
    foreach ($pattern in $forbiddenResourceValuePatterns) {
      if ($value -match $pattern) {
        $resourceMatches += "${relativePath}:$($entry.name) matches '$pattern'"
      }
    }
  }
}

if ($resourceMatches.Count -gt 0) {
  throw "Runtime resource strings expose internal debug/migration copy: $($resourceMatches -join '; ')"
}

Write-Host 'runtime UI debug-field check passed'
