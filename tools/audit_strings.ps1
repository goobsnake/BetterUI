
$content = Get-Content "lang\en.lua" -Raw
$defined = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

$used = Get-Content "used_strings.txt"

$definedSet = New-Object System.Collections.Generic.HashSet[string]
$defined | ForEach-Object { $definedSet.Add($_) } | Out-Null

$usedSet = New-Object System.Collections.Generic.HashSet[string]
$used | ForEach-Object { $usedSet.Add($_) } | Out-Null

Write-Host "Unused strings (defined in en.lua but not found in codebase):"
$defined | Where-Object { -not $usedSet.Contains($_) } | Sort-Object

Write-Host "`nMissing strings (found in codebase but not in en.lua):"
$used | Where-Object { -not $definedSet.Contains($_) } | Sort-Object
