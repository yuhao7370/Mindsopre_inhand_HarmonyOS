$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtureRoot = Join-Path $projectRoot 'entry\src\ohosTest\resources\rawfile\fixtures\segmentation'
$fixturePath = Join-Path $fixtureRoot 'person.jpg'
$maskPath = Join-Path $fixtureRoot 'person_mask.png'
$noticePath = Join-Path $fixtureRoot 'NOTICE.md'
$testSourcePath = Join-Path $projectRoot 'entry\src\ohosTest\ets\test\SegmentationNative.test.ets'
$testSource = Get-Content -LiteralPath $testSourcePath -Raw

foreach ($marker in @(
  'const personFixturePath: string = ''fixtures/segmentation/person.jpg'';',
  'const personMaskPath: string = ''fixtures/segmentation/person_mask.png'';',
  'createModuleContext(''entry_test'').resourceManager',
  'const expectedForeground = expectedMaskRgba[offset + 3] > foregroundAlphaThreshold;'
)) {
  if (-not $testSource.Contains($marker)) {
    throw ('Segmentation fixture contract is missing source marker: {0}' -f $marker)
  }
}
foreach ($marker in @(
  'const personFixturePath: string = ''posenet/skeleton_image.JPG'';',
  'foregroundChannelThreshold',
  'expectedRgba[offset] <',
  'expectedRgba[offset + 1] <',
  'expectedRgba[offset + 2] <'
)) {
  if ($testSource.Contains($marker)) {
    throw ('Segmentation fixture contract still contains the old implicit oracle: {0}' -f $marker)
  }
}

$contracts = @(
  [pscustomobject]@{ Path = $fixturePath; Hash = 'D203D1DACD8E5976D27405E2932BBAF4E6FD1CD3B0F026FE6EC8AEF72E2E72AE' },
  [pscustomobject]@{ Path = $maskPath; Hash = '12E92A228615D333E5791AF039A61842044DFEF43DC1DE963F9F56D71B10CAF7' }
)
foreach ($contract in $contracts) {
  if (-not (Test-Path -LiteralPath $contract.Path -PathType Leaf)) {
    throw ('Segmentation fixture is missing: {0}' -f $contract.Path)
  }
  $actualHash = (Get-FileHash -LiteralPath $contract.Path -Algorithm SHA256).Hash
  if ($actualHash -cne $contract.Hash) {
    throw ('Segmentation fixture SHA-256 mismatch: {0}: {1}' -f $contract.Path, $actualHash)
  }
}

$fixture = [Drawing.Image]::FromFile($fixturePath)
$mask = [Drawing.Bitmap]::FromFile($maskPath)
try {
  if ($fixture.Width -ne 3000 -or $fixture.Height -ne 4000 -or
      $mask.Width -ne $fixture.Width -or $mask.Height -ne $fixture.Height) {
    throw 'Segmentation fixture and mask must both be exactly 3000x4000.'
  }
  $rect = New-Object Drawing.Rectangle 0, 0, $mask.Width, $mask.Height
  $data = $mask.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $stride = [Math]::Abs($data.Stride)
    $bytes = New-Object byte[] ($stride * $mask.Height)
    [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $foreground = 0
    for ($y = 0; $y -lt $mask.Height; $y++) {
      for ($x = 0; $x -lt $mask.Width; $x++) {
        $alpha = $bytes[$y * $stride + $x * 4 + 3]
        if ($alpha -eq 255) { $foreground++ }
        elseif ($alpha -ne 0) {
          throw ('Segmentation mask alpha is not binary at ({0},{1}): {2}' -f $x, $y, $alpha)
        }
      }
    }
    $ratio = $foreground / ($mask.Width * $mask.Height)
    if ($ratio -le 0.01 -or $ratio -ge 0.99) {
      throw ('Segmentation mask foreground/background is trivial: {0}' -f $ratio)
    }
  } finally {
    $mask.UnlockBits($data)
  }
} finally {
  $fixture.Dispose()
  $mask.Dispose()
}

$notice = Get-Content -Raw -LiteralPath $noticePath
foreach ($marker in @(
  'JSC2016-E-016505',
  'oldid=948780982',
  'PD-USGov-NASA',
  'D203D1DACD8E5976D27405E2932BBAF4E6FD1CD3B0F026FE6EC8AEF72E2E72AE',
  '12E92A228615D333E5791AF039A61842044DFEF43DC1DE963F9F56D71B10CAF7',
  'The production segmentation model and its output were not used to create the mask.'
)) {
  if (-not $notice.Contains($marker)) {
    throw ('Segmentation fixture NOTICE is missing: {0}' -f $marker)
  }
}

Write-Host ('Segmentation fixture contract passed: binary-alpha foreground ratio {0}.' -f $ratio)
