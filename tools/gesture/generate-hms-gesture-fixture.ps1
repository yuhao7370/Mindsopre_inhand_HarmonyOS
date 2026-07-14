param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$inputFull = [IO.Path]::GetFullPath($InputPath)
$outputFull = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFull.StartsWith("$repoRoot\", [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Fixture output must stay inside the repository.'
}
Add-Type -AssemblyName System.Drawing
$source = New-Object System.Drawing.Bitmap($inputFull)
$scaled = New-Object System.Drawing.Bitmap(32, 32, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
  if ($source.Width -le 0 -or $source.Height -le 0) { throw 'Fixture image dimensions are invalid.' }
  $graphics = [Drawing.Graphics]::FromImage($scaled)
  try {
    $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.DrawImage($source, 0, 0, 32, 32)
  } finally {
    $graphics.Dispose()
  }
  $values = [Collections.Generic.List[int]]::new()
  for ($y = 0; $y -lt 32; $y++) {
    for ($x = 0; $x -lt 32; $x++) {
      $pixel = $scaled.GetPixel($x, $y)
      $values.Add($pixel.R); $values.Add($pixel.G); $values.Add($pixel.B); $values.Add($pixel.A)
    }
  }
  if ($values.Count -ne 4096 -or @($values | Where-Object { $_ -lt 0 -or $_ -gt 255 }).Count -ne 0) {
    throw 'Generated RGBA fixture is invalid.'
  }
  $rows = [Collections.Generic.List[string]]::new()
  for ($offset = 0; $offset -lt $values.Count; $offset += 32) {
    $end = [Math]::Min($offset + 31, $values.Count - 1)
    $rows.Add('  ' + (($values[$offset..$end] | ForEach-Object { $_.ToString() }) -join ', ') + ',')
  }
  $content = @(
    'export const openPalmGestureFixtureWidth: number = 32;',
    'export const openPalmGestureFixtureHeight: number = 32;',
    'const openPalmGestureFixtureValues: Array<number> = [',
    ($rows -join "`n"),
    '];',
    'export function openPalmGestureFixtureRgba(): Uint8Array {',
    '  return new Uint8Array(openPalmGestureFixtureValues);',
    '}',
    ''
  ) -join "`n"
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFull)) | Out-Null
  [IO.File]::WriteAllText($outputFull, $content, [Text.UTF8Encoding]::new($false))
} finally {
  $scaled.Dispose()
  $source.Dispose()
}
