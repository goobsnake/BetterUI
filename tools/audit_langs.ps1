
$enContent = Get-Content "lang\en.lua" -Raw
$enKeys = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$enSet = New-Object System.Collections.Generic.HashSet[string]
$enKeys | ForEach-Object { $enSet.Add($_) } | Out-Null

$langs = Get-ChildItem "lang\*.lua" | Where-Object { $_.Name -ne "en.lua" }

foreach ($langFile in $langs) {
    Write-Host "`n--- Auditing $($langFile.Name) ---"
    $content = Get-Content $langFile.FullName -Raw
    $keys = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $keySet = New-Object System.Collections.Generic.HashSet[string]
    $keys | ForEach-Object { $keySet.Add($_) } | Out-Null
    
    $missing = $enKeys | Where-Object { -not $keySet.Contains($_) }
    if ($missing) {
        Write-Host "Missing keys (present in en.lua but not in $($langFile.Name)) [Count: $($missing.Count)]:"
        $missing | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
        if ($missing.Count -gt 10) { Write-Host "  ... and $($missing.Count - 10) more" }
    }
    else {
        Write-Host "No missing keys."
    }
    
    $extra = $keys | Where-Object { -not $enSet.Contains($_) }
    if ($extra) {
        Write-Host "Extra keys (present in $($langFile.Name) but not in en.lua) [Count: $($extra.Count)]:"
        $extra | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
        if ($extra.Count -gt 10) { Write-Host "  ... and $($extra.Count - 10) more" }
    }
}
