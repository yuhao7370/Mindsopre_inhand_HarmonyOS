$ErrorActionPreference = 'Stop'

$path = Join-Path (Split-Path -Parent $PSScriptRoot) 'entry\src\main\resources\base\media\feature_digit.png'
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
  throw "Missing handwritten digit icon: $path"
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::new($path)
try {
  if ($bitmap.Width -ne 256 -or $bitmap.Height -ne 256) {
    throw "Handwritten digit icon must be 256x256, got $($bitmap.Width)x$($bitmap.Height)"
  }
  if (-not (($bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha) -ne 0)) {
    throw "Handwritten digit icon must include an alpha channel, got $($bitmap.PixelFormat)"
  }

  $pixelCount = $bitmap.Width * $bitmap.Height
  $transparent = 0
  $semiTransparent = 0
  $neutralBackground = 0
  $colored = 0
  for ($y = 0; $y -lt $bitmap.Height; $y++) {
    for ($x = 0; $x -lt $bitmap.Width; $x++) {
      $pixel = $bitmap.GetPixel($x, $y)
      if ($pixel.A -eq 0) {
        $transparent += 1
        continue
      }
      if ($pixel.A -lt 255) {
        $semiTransparent += 1
      }
      $chroma = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B)) - [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
      if ($pixel.A -ge 64 -and $chroma -le 18) {
        $neutralBackground += 1
      }
      if ($pixel.A -ge 64) {
        if ($chroma -lt 40 -or $pixel.B -lt $pixel.R -or $pixel.B -lt ($pixel.G - 8)) {
          throw "Unexpected significant non-transparent icon pixel at ($x,$y): $($pixel.ToArgb())"
        }
        $colored += 1
      }
    }
  }

  if (($transparent / $pixelCount) -le 0.55) {
    throw "Transparent pixels must be a majority, got $transparent of $pixelCount"
  }
  if ($semiTransparent -eq 0) {
    throw 'Handwritten digit icon must retain semi-transparent antialiased edges.'
  }
  if ($neutralBackground -ne 0) {
    throw "Handwritten digit icon contains $neutralBackground opaque/semi-opaque neutral background pixels."
  }
  if ($colored -lt 200) {
    throw "Handwritten digit icon has too little colored line art: $colored significant pixels"
  }
  foreach ($point in @(@(0, 0), @(255, 0), @(0, 255), @(255, 255))) {
    if ($bitmap.GetPixel($point[0], $point[1]).A -ne 0) {
      throw "Handwritten digit icon corner ($($point[0]),$($point[1])) must be transparent."
    }
  }
  Write-Output "Handwritten digit icon guard passed: transparent=$transparent semi=$semiTransparent colored=$colored"
}
finally {
  $bitmap.Dispose()
}
