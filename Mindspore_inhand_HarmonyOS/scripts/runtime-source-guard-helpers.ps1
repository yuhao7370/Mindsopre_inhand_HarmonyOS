function Remove-RuntimeSourceComments([string]$Text) {
  $withoutComments = [regex]::Replace($Text, '(?ms)/\*.*?\*/|//[^\n]*', '')
  return [regex]::Replace($withoutComments, '(?s)`[^`]*`', '')
}

function Get-RuntimeOuterActionChain(
  [string]$Text,
  [string]$ImageLinePattern,
  [string]$ActionName
) {
  $match = [regex]::Match($Text, "(?m)^[\t ]*$ImageLinePattern[\t ]*$")
  if (-not $match.Success) {
    throw "$ActionName must render one real icon image."
  }
  $actionStart = $Text.LastIndexOf('Row() {', $match.Index, [StringComparison]::Ordinal)
  if ($actionStart -lt 0) {
    throw "$ActionName icon must be inside an action Row."
  }
  $openBrace = $Text.IndexOf('{', $actionStart, [StringComparison]::Ordinal)
  $depth = 0
  $closeBrace = -1
  for ($index = $openBrace; $index -lt $Text.Length; $index++) {
    if ($Text[$index] -eq '{') { $depth++ }
    elseif ($Text[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        $closeBrace = $index
        break
      }
    }
  }
  if ($closeBrace -lt 0) {
    throw "$ActionName action Row is not balanced."
  }
  $chain = [Collections.Generic.List[string]]::new()
  foreach ($line in $Text.Substring($closeBrace + 1).Split("`n")) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0) { continue }
    if (-not $trimmed.StartsWith('.')) { break }
    $chain.Add($trimmed)
  }
  return ($chain -join "`n")
}

function Assert-RuntimeSemanticAction(
  [string]$Chain,
  [string]$AccessibilityPattern,
  [string]$Role,
  [string]$HandlerPattern,
  [string]$ActionName
) {
  if ($Chain -notmatch '(?m)^\.width\(48\)$' -or
    $Chain -notmatch '(?m)^\.height\(48\)$' -or
    $Chain -match '(?m)^\.(?:width|height)\((?:35|40)\)$' -or
    $Chain -notmatch "(?m)^$AccessibilityPattern$" -or
    $Chain -notmatch "(?m)^\.accessibilityRole\(AccessibilityRoleType\.$Role\)$" -or
    $Chain -notmatch "(?m)^\.onClick\(\(\) => $HandlerPattern\)$") {
    throw "$ActionName must keep its handler in a localized 48vp semantic outer target."
  }
}
