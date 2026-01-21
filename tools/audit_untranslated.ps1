
$enContent = Get-Content "lang\en.lua" -Raw
$enMatches = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)",\s*"([^"]+)"\)')
$enMap = @{}
foreach ($m in $enMatches) {
    # Key -> Value
    $enMap[$m.Groups[1].Value] = $m.Groups[2].Value
}

$langs = Get-ChildItem "lang\*.lua" | Where-Object { $_.Name -ne "en.lua" }

foreach ($langFile in $langs) {
    Write-Host "`n--- Checking $($langFile.Name) for untranslated strings ---"
    $content = Get-Content $langFile.FullName -Raw
    # Simple regex, might fail on escaped quotes, but good enough for now
    $matches = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)",\s*"(.*)"\)')
    
    $untranslatedCount = 0
    foreach ($m in $matches) {
        $key = $m.Groups[1].Value
        $val = $m.Groups[2].Value
        
        if ($enMap.ContainsKey($key)) {
            $enVal = $enMap[$key]
            if ($val -eq $enVal -and $val.Length -gt 2) {
                # Ignore short strings like "AP" or numbers
                # Write-Host "  $key: '$val' (Same as English)"
                $untranslatedCount++
            }
        }
    }
    Write-Host "Found $untranslatedCount potentially untranslated strings."
}
