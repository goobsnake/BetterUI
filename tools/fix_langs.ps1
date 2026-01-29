<#
.SYNOPSIS
    Syncs all language files with en.lua as the source of truth.
    
.DESCRIPTION
    This script:
    1. Adds any strings from en.lua that are missing in other language files (using English as placeholder)
    2. Removes any extra strings from other language files that don't exist in en.lua
    3. Reports changes made to each file
    
.NOTES
    Run from the tools directory: .\fix_langs.ps1
#>

$ErrorActionPreference = "Stop"
$toolsDir = $PSScriptRoot
$root = Resolve-Path "$toolsDir\.."
$langDir = "$root\lang"
$enPath = "$langDir\en.lua"

Write-Host "=== BetterUI Language File Sync ===" -ForegroundColor Cyan
Write-Host "Source of truth: en.lua"
Write-Host ""

# Parse en.lua to get all keys and their values (handles multi-line strings)
$enContent = Get-Content $enPath -Raw

# Regex that handles both single-line and multi-line ZO_CreateStringId patterns
$pattern = 'ZO_CreateStringId\("([^"]+)",\s*"((?:[^"\\]|\\.|(?:"\s*\.\.\s*"))*)"'
# Also try a simpler pattern to catch more cases
$simplePattern = 'ZO_CreateStringId\("([^"]+)",[\s\r\n]*"([^"]*)"'

$enMatches = [regex]::Matches($enContent, $simplePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$enMap = [ordered]@{}
foreach ($m in $enMatches) {
    $key = $m.Groups[1].Value
    $value = $m.Groups[2].Value
    if (-not $enMap.Contains($key)) {
        $enMap[$key] = $value
    }
}

Write-Host "Found $($enMap.Count) strings in en.lua" -ForegroundColor Green

# Get order of strings in en.lua for proper insertion
$enKeys = $enMap.Keys

# Process each language file
$langFiles = Get-ChildItem "$langDir\*.lua" | Where-Object { $_.Name -ne "en.lua" }

foreach ($langFile in $langFiles) {
    Write-Host "`n--- Processing $($langFile.Name) ---" -ForegroundColor Yellow
    
    $content = Get-Content $langFile.FullName -Raw
    $langMatches = [regex]::Matches($content, $simplePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $langMap = @{}
    foreach ($m in $langMatches) {
        $key = $m.Groups[1].Value
        $value = $m.Groups[2].Value
        if (-not $langMap.ContainsKey($key)) {
            $langMap[$key] = $value
        }
    }
    
    $langSet = New-Object System.Collections.Generic.HashSet[string]
    $langMap.Keys | ForEach-Object { $langSet.Add($_) } | Out-Null
    
    # Find missing keys (in en.lua but not in this lang file)
    $missing = $enKeys | Where-Object { -not $langSet.Contains($_) }
    
    # Find extra keys (in this lang file but not in en.lua)
    $extra = $langMap.Keys | Where-Object { -not $enMap.Contains($_) }
    
    $addedCount = 0
    $removedCount = 0
    $newContent = $content
    
    # Remove extra keys (handles multi-line patterns)
    foreach ($key in $extra) {
        # Pattern to match the full ZO_CreateStringId call including multi-line values
        $removePattern = "ZO_CreateStringId\(`"$key`",[\s\r\n]*`"[^`"]*`"\)[^\r\n]*\r?\n?"
        $newContent = $newContent -replace $removePattern, ''
        $removedCount++
    }
    
    # Add missing keys (insert after the last key in the file, or at end)
    if ($missing.Count -gt 0) {
        $insertLines = @()
        foreach ($key in $missing) {
            $enValue = $enMap[$key]
            # Escape any special characters for Lua string
            $escapedValue = $enValue -replace '\\', '\\\\' -replace '"', '\"'
            # Use English value as placeholder with TODO marker for translation
            $insertLines += "ZO_CreateStringId(`"$key`", `"$escapedValue`") -- TODO: Translate"
        }
        
        # Find the last ZO_CreateStringId line and insert after it
        $lines = $newContent -split "`r?`n"
        $lastIndex = -1
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match 'ZO_CreateStringId') {
                $lastIndex = $i
                break
            }
        }
        
        if ($lastIndex -ge 0) {
            $insertBlock = "`r`n-- Added from en.lua (TODO: Translate)`r`n" + ($insertLines -join "`r`n")
            $lines[$lastIndex] = $lines[$lastIndex] + $insertBlock
            $newContent = $lines -join "`r`n"
        }
        
        $addedCount = $missing.Count
    }
    
    # Write back if changes were made
    if ($addedCount -gt 0 -or $removedCount -gt 0) {
        Set-Content $langFile.FullName $newContent -NoNewline
        Write-Host "  Added: $addedCount strings" -ForegroundColor Green
        Write-Host "  Removed: $removedCount strings" -ForegroundColor Red
    }
    else {
        Write-Host "  No changes needed." -ForegroundColor Gray
    }
}

# Cleanup temp files
Remove-Item "$toolsDir\missing_in_de.txt" -ErrorAction SilentlyContinue
Remove-Item "$toolsDir\extra_in_de.txt" -ErrorAction SilentlyContinue

Write-Host "`n=== Sync Complete ===" -ForegroundColor Cyan
Write-Host "Run LocalizationAudit.ps1 to verify changes." -ForegroundColor Gray
