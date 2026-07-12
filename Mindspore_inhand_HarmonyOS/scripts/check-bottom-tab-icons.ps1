$root = Split-Path -Parent $PSScriptRoot
$appStatePath = Join-Path $root 'entry/src/main/ets/app/AppState.ets'
$bottomTabPath = Join-Path $root 'entry/src/main/ets/common/components/BottomTabBar.ets'
$mediaRoot = Join-Path $root 'entry/src/main/resources/base/media'

$appState = Get-Content -Raw -Encoding UTF8 -LiteralPath $appStatePath
$bottomTab = Get-Content -Raw -Encoding UTF8 -LiteralPath $bottomTabPath

$expectedMedia = @(
  @{ Name = 'experience_checked'; Hash = '802269A6A418A71870F124A84EEF35AF157D37341D7C17E68D493EAE28FC0A24' },
  @{ Name = 'experience_uncheck'; Hash = '97455FE77475F8C208E510C02E396A207060DF931AEFCC12C28638634BD21C83' },
  # Android resource is college_checked.png; Harmony uses a suffixed name to avoid
  # confusion with the existing app.string.college_checked text resource.
  @{ Name = 'college_checked_icon'; Hash = '82627727DE2E781219C1F3DECAB3B4F4F7B4ACF019EFF9CB0C21107107260F43' },
  @{ Name = 'college_uncheck'; Hash = '10A8A1CB907C9E563D60F995770DF8254DF8834A8498DA440050338E120182DB' },
  @{ Name = 'me_checked'; Hash = 'EEBB941B42C64F835105154673902FAA91FD6EEB6809611F179C1723CC80531D' },
  @{ Name = 'me_uncheck'; Hash = 'B6B2E698F6D6E76B77ED8E8C828207A4EF0E44D824122BF00560C392A41E54C7' }
)

foreach ($entry in $expectedMedia) {
  $mediaName = $entry.Name
  if ($appState.IndexOf($mediaName) -lt 0) {
    throw "Bottom tab AppState is missing Android tab media name: $mediaName"
  }

  $mediaPath = Join-Path $mediaRoot "$mediaName.png"
  if (-not (Test-Path -LiteralPath $mediaPath)) {
    throw "Missing migrated Android bottom tab media asset: $mediaPath"
  }

  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mediaPath).Hash
  if ($actualHash -ne $entry.Hash) {
    throw "Android bottom tab media asset hash changed for ${mediaName}: expected $($entry.Hash), got $actualHash"
  }
}

if ($bottomTab.IndexOf('Image(') -lt 0) {
  throw 'BottomTabBar must render Android tab PNG media with Image(), not text-only symbolic icons.'
}

if ($bottomTab.IndexOf('iconLabel(tab.icon)') -ge 0) {
  throw 'BottomTabBar still renders symbolic icon labels instead of Android selected/unselected tab media.'
}

Write-Host 'bottom tab Android media icon wiring is present'
