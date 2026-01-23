$ErrorActionPreference = "Stop"
$toolsDir = $PSScriptRoot
$report = "$toolsDir\audit_report.md"
$usedStringsFile = "$toolsDir\used_strings.txt"
$root = Resolve-Path "$toolsDir\.."

# =============================================================================
# Helper Functions
# =============================================================================

Function Write-AuditSection ($title) {
    Write-Host "`n$title" -ForegroundColor Cyan
    "`n## $title" | Add-Content $report
}

# =============================================================================
# 1. Generate Used Strings
# =============================================================================
Function Get-UsedStrings {
    Write-AuditSection "1. Generating Used Strings List"
    Write-Host "Scanning $root for used strings..."
    
    $files = Get-ChildItem -Path $root -Recurse -Include *.lua, *.xml
    $strings = New-Object System.Collections.Generic.HashSet[string]
    
    foreach ($file in $files) {
        # Skip tools, agent, and lang directories to avoid self-reference
        if ($file.FullName -like "*\tools\*" -or $file.FullName -like "*\.agent*" -or $file.FullName -like "*\lang\*") { continue }
        
        $content = Get-Content $file.FullName -Raw
        if ([string]::IsNullOrEmpty($content)) { continue }

        $mList = [regex]::Matches($content, 'SI_BETTERUI_[A-Z0-9_]+')
        foreach ($m in $mList) {
            $strings.Add($m.Value) | Out-Null
        }
    }
    
    $strings | Sort-Object | Set-Content $usedStringsFile
    $msg = "Found $($strings.Count) unique strings. Saved to $usedStringsFile"
    Write-Host $msg
    " $msg" | Add-Content $report
}

# =============================================================================
# 2. Audit Language Keys
# =============================================================================
Function Test-LanguageKeys {
    Write-AuditSection "2. Auditing Language Keys"
    
    $langDir = Resolve-Path "$root\lang"
    $enPath = Join-Path $langDir "en.lua"
    
    $enContent = Get-Content $enPath -Raw
    $enKeys = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $enSet = New-Object System.Collections.Generic.HashSet[string]
    $enKeys | ForEach-Object { $enSet.Add($_) } | Out-Null
    
    # Validation: Check for naming convention
    $badKeys = $enKeys | Where-Object { $_ -notmatch '^SI_BETTERUI_' }
    if ($badKeys) {
        $msg = "WARNING: Finding keys violating naming convention (must start with SI_BETTERUI_):"
        Write-Host "`n$msg" -ForegroundColor Yellow
        "`n $msg" | Add-Content $report
        foreach ($k in $badKeys) {
            Write-Host "  $k"
            "     $k" | Add-Content $report
        }
    }
    else {
        "All keys in en.lua follow naming convention." | Add-Content $report
    }
    
    $langs = Get-ChildItem "$langDir\*.lua" | Where-Object { $_.Name -ne "en.lua" }
    
    foreach ($langFile in $langs) {
        Write-Host "`n--- Auditing $($langFile.Name) ---"
        "`n - - -   A u d i t i n g   $($langFile.Name)   - - -" | Add-Content $report
        
        $content = Get-Content $langFile.FullName -Raw
        $keys = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        $keySet = New-Object System.Collections.Generic.HashSet[string]
        $keys | ForEach-Object { $keySet.Add($_) } | Out-Null
        
        $missing = $enKeys | Where-Object { -not $keySet.Contains($_) }
        if ($missing) {
            $msg = "Missing keys (present in en.lua but not in $($langFile.Name)) [Count: $($missing.Count)]:"
            Write-Host $msg
            " $msg" | Add-Content $report
            
            $limit = 0
            foreach ($m in $missing) {
                if ($limit -lt 10) {
                    Write-Host "  $m"
                    "     $m" | Add-Content $report
                }
                $limit++
            }
            if ($limit -gt 10) {
                Write-Host "  ... and $($limit - 10) more"
                "     . . .   a n d   $($limit - 10)   m o r e" | Add-Content $report
            }
        }
        else {
            " No missing keys." | Add-Content $report
        }
    }
}

# =============================================================================
# 3. Audit String Usage
# =============================================================================
Function Test-StringUsage {
    Write-AuditSection "3. Auditing String Usage"
    
    $langDir = Resolve-Path "$root\lang"
    $enPath = Join-Path $langDir "en.lua"
    
    if (-not (Test-Path $usedStringsFile)) {
        Write-Error "used_strings.txt not found."
    }
    
    $content = Get-Content $enPath -Raw
    $defined = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $used = Get-Content $usedStringsFile
    
    $definedSet = New-Object System.Collections.Generic.HashSet[string]
    $defined | ForEach-Object { $definedSet.Add($_) } | Out-Null
    
    $usedSet = New-Object System.Collections.Generic.HashSet[string]
    $used | ForEach-Object { $usedSet.Add($_) } | Out-Null
    
    "Unused strings (defined in en.lua but not found in codebase):" | Add-Content $report
    $unused = $defined | Where-Object { -not $usedSet.Contains($_) } | Sort-Object
    foreach ($u in $unused) {
        " $u" | Add-Content $report
    }

    "`n Missing strings (found in codebase but not in en.lua):" | Add-Content $report
    $missing = $used | Where-Object { -not $definedSet.Contains($_) } | Sort-Object
    foreach ($m in $missing) {
        " $m" | Add-Content $report
    }
}

# =============================================================================
# 4. Audit Untranslated Strings
# =============================================================================
Function Test-Untranslated {
    Write-AuditSection "4. Auditing Untranslated Strings"
    
    $langDir = Resolve-Path "$root\lang"
    $enPath = Join-Path $langDir "en.lua"
    
    $enContent = Get-Content $enPath -Raw
    $enMatches = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)",\s*"(.*)"\)')
    $enMap = @{}
    foreach ($m in $enMatches) {
        $enMap[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    
    $langs = Get-ChildItem "$langDir\*.lua" | Where-Object { $_.Name -ne "en.lua" }
    
    foreach ($langFile in $langs) {
        Write-Host "`n--- Checking $($langFile.Name) ---"
        "`n - - -   C h e c k i n g   $($langFile.Name)   - - -" | Add-Content $report
        
        $content = Get-Content $langFile.FullName -Raw
        $mList = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)",\s*"(.*)"\)')
        
        $cnt = 0
        foreach ($m in $mList) {
            $key = $m.Groups[1].Value
            $val = $m.Groups[2].Value
            
            if ($enMap.ContainsKey($key)) {
                $enVal = $enMap[$key]
                if ($val -eq $enVal -and $val.Length -gt 2) {
                    $cnt++
                }
            }
        }
        " Found $cnt potentially untranslated strings." | Add-Content $report
    }
}

# =============================================================================
# Main Execution
# =============================================================================
"# BetterUI Localization Audit" | Set-Content $report
"Date: $(Get-Date)" | Add-Content $report
"---" | Add-Content $report

Get-UsedStrings
Test-LanguageKeys
Test-StringUsage
Test-Untranslated

Write-Host "`nAudit complete. Report saved to $report" -ForegroundColor Green
