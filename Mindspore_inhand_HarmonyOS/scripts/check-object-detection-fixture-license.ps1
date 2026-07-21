param(
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$noticePath = Join-Path $SourceRoot 'entry\src\ohosTest\resources\rawfile\fixtures\classification\NOTICE.md'
$fixturePath = Join-Path $SourceRoot 'entry\src\ohosTest\resources\rawfile\fixtures\classification\yellow_labrador.jpg'
if (-not (Test-Path -LiteralPath $noticePath -PathType Leaf)) {
  throw 'Object-detection fixture license guard failed: NOTICE.md is missing.'
}
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
  throw 'Object-detection fixture license guard failed: yellow_labrador.jpg is missing.'
}

$notice = [IO.File]::ReadAllText($noticePath)
$requiredStatements = @(
  'Selected redistribution license: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0).',
  'License URI: https://creativecommons.org/licenses/by-sa/3.0/',
  'Original photograph by Elf; derivative work by Djmirko; retouched by FT2.',
  'Project changes to the image bytes: none; this is the unchanged 700x577 Wikimedia Commons file.',
  'The project-authored detection box is separate test metadata and is not embedded in the image.'
)
foreach ($statement in $requiredStatements) {
  if ($notice.IndexOf($statement, [StringComparison]::Ordinal) -lt 0) {
    throw "Object-detection fixture license guard failed: missing redistribution statement: $statement"
  }
}

$actualHash = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
if ($actualHash -cne 'D4CB12EA8A768582562E1F1C0C930EA6FC4757F5B66551B986B41498EFD75CA1') {
  throw "Object-detection fixture license guard failed: yellow_labrador.jpg SHA-256 mismatch: $actualHash"
}

Write-Output 'Object-detection fixture redistribution notice and bytes are valid.'
