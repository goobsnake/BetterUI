<#
.SYNOPSIS
Unified localization maintenance for BetterUI.

.DESCRIPTION
Combines language sync and localization audit in one script.

Modes:
- `Sync`: synchronize non-English language files against `lang/en.lua`
- `Audit`: generate localization audit outputs
- `SyncAndAudit`: run sync first, then audit (recommended)

.PARAMETER Mode
Execution mode. Defaults to `SyncAndAudit`.

.PARAMETER RootDir
Repository root path. Defaults to this script's parent directory.

.PARAMETER ReportPath
Path for audit report markdown output.

.PARAMETER UsedStringsPath
Path for intermediate used-string key output.

.EXAMPLE
.\LanguageMaintenance.ps1

.EXAMPLE
.\LanguageMaintenance.ps1 -Mode Sync

.EXAMPLE
.\LanguageMaintenance.ps1 -Mode Audit -ReportPath '.\tools\audit_report.md'
#>
param(
    [ValidateSet('Sync', 'Audit', 'SyncAndAudit')]
    [string]$Mode = 'SyncAndAudit',
    [string]$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot 'audit_report.md'),
    [string]$UsedStringsPath = (Join-Path $PSScriptRoot 'used_strings.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LangContext {
    param([string]$RepositoryRoot)

    $langDir = Join-Path $RepositoryRoot 'lang'
    $enPath = Join-Path $langDir 'en.lua'

    if (-not (Test-Path -LiteralPath $langDir -PathType Container)) {
        throw "Language directory not found: $langDir"
    }
    if (-not (Test-Path -LiteralPath $enPath -PathType Leaf)) {
        throw "English language file not found: $enPath"
    }

    return @{
        LangDir = $langDir
        EnPath  = $enPath
    }
}

function Get-EnStringMap {
    param([string]$EnPath)

    $pattern = 'ZO_CreateStringId\("([^"]+)",[\s\r\n]*"([^"]*)"'
    $enContent = Get-Content -LiteralPath $EnPath -Raw
    $enMatches = [regex]::Matches($enContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $map = [ordered]@{}
    foreach ($match in $enMatches) {
        $key = $match.Groups[1].Value
        $value = $match.Groups[2].Value
        if (-not $map.Contains($key)) {
            $map[$key] = $value
        }
    }

    return $map
}

function Invoke-LanguageSync {
    param(
        [string]$LangDir,
        [string]$EnPath
    )

    Write-Host '=== BetterUI Language File Sync ===' -ForegroundColor Cyan
    Write-Host 'Source of truth: en.lua'
    Write-Host ''

    $enMap = Get-EnStringMap -EnPath $EnPath
    $enKeys = $enMap.Keys
    Write-Host "Found $($enMap.Count) strings in en.lua" -ForegroundColor Green

    $pattern = 'ZO_CreateStringId\("([^"]+)",[\s\r\n]*"([^"]*)"'
    $langFiles = Get-ChildItem -LiteralPath $LangDir -Filter '*.lua' | Where-Object { $_.Name -ne 'en.lua' }

    foreach ($langFile in $langFiles) {
        Write-Host "`n--- Processing $($langFile.Name) ---" -ForegroundColor Yellow

        $content = Get-Content -LiteralPath $langFile.FullName -Raw
        $langMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

        $langMap = @{}
        foreach ($match in $langMatches) {
            $key = $match.Groups[1].Value
            $value = $match.Groups[2].Value
            if (-not $langMap.ContainsKey($key)) {
                $langMap[$key] = $value
            }
        }

        $langSet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($key in $langMap.Keys) {
            $langSet.Add($key) | Out-Null
        }

        $missing = @($enKeys | Where-Object { -not $langSet.Contains($_) })
        $extra = @($langMap.Keys | Where-Object { -not $enMap.Contains($_) })

        $newContent = $content
        $removedCount = 0
        foreach ($key in $extra) {
            $removePattern = "ZO_CreateStringId\(`"$key`",[\s\r\n]*`"[^`"]*`"\)[^\r\n]*\r?\n?"
            $newContent = $newContent -replace $removePattern, ''
            $removedCount++
        }

        $addedCount = 0
        if ($missing.Count -gt 0) {
            $insertLines = foreach ($key in $missing) {
                $escaped = ($enMap[$key] -replace '\\', '\\\\' -replace '"', '\"')
                "ZO_CreateStringId(`"$key`", `"$escaped`") -- TODO: Translate"
            }

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
            else {
                $newContent = $newContent + "`r`n-- Added from en.lua (TODO: Translate)`r`n" + ($insertLines -join "`r`n")
            }

            $addedCount = $missing.Count
        }

        if ($addedCount -gt 0 -or $removedCount -gt 0) {
            Set-Content -LiteralPath $langFile.FullName -Value $newContent -NoNewline
            Write-Host "  Added: $addedCount strings" -ForegroundColor Green
            Write-Host "  Removed: $removedCount strings" -ForegroundColor Red
        }
        else {
            Write-Host '  No changes needed.' -ForegroundColor Gray
        }
    }

    Write-Host "`n=== Sync Complete ===" -ForegroundColor Cyan
}

function Write-AuditSection {
    param(
        [string]$Title,
        [string]$OutputPath
    )

    Write-Host "`n$Title" -ForegroundColor Cyan
    "`n## $Title" | Add-Content -LiteralPath $OutputPath
}

function Invoke-LanguageAudit {
    param(
        [string]$RepositoryRoot,
        [string]$LangDir,
        [string]$EnPath,
        [string]$OutputPath,
        [string]$UsedPath
    )

    "# BetterUI Localization Audit" | Set-Content -LiteralPath $OutputPath
    "Date: $(Get-Date)" | Add-Content -LiteralPath $OutputPath
    '---' | Add-Content -LiteralPath $OutputPath

    Write-AuditSection -Title '1. Generating Used Strings List' -OutputPath $OutputPath
    Write-Host "Scanning $RepositoryRoot for used strings..."

    $files = Get-ChildItem -Path $RepositoryRoot -Recurse -Include *.lua, *.xml -File
    $strings = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($file in $files) {
        if ($file.FullName -like '*\tools\*' -or $file.FullName -like '*\.agent\*' -or $file.FullName -like '*\lang\*') {
            continue
        }

        $content = Get-Content -LiteralPath $file.FullName -Raw
        if ([string]::IsNullOrEmpty($content)) {
            continue
        }

        $matches = [regex]::Matches($content, 'SI_BETTERUI_[A-Z0-9_]+')
        foreach ($match in $matches) {
            $strings.Add($match.Value) | Out-Null
        }
    }

    $strings | Sort-Object | Set-Content -LiteralPath $UsedPath
    $usedMsg = "Found $($strings.Count) unique strings. Saved to $UsedPath"
    Write-Host $usedMsg
    " $usedMsg" | Add-Content -LiteralPath $OutputPath

    Write-AuditSection -Title '2. Auditing Language Keys' -OutputPath $OutputPath
    $enContent = Get-Content -LiteralPath $EnPath -Raw
    $enKeys = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

    $badKeys = @($enKeys | Where-Object { $_ -notmatch '^SI_BETTERUI_' })
    if ($badKeys.Count -gt 0) {
        $warning = 'WARNING: Finding keys violating naming convention (must start with SI_BETTERUI_):'
        Write-Host "`n$warning" -ForegroundColor Yellow
        "`n $warning" | Add-Content -LiteralPath $OutputPath
        foreach ($key in $badKeys) {
            Write-Host "  $key"
            "     $key" | Add-Content -LiteralPath $OutputPath
        }
    }
    else {
        'All keys in en.lua follow naming convention.' | Add-Content -LiteralPath $OutputPath
    }

    $langs = Get-ChildItem -LiteralPath $LangDir -Filter '*.lua' | Where-Object { $_.Name -ne 'en.lua' }
    foreach ($langFile in $langs) {
        Write-Host "`n--- Auditing $($langFile.Name) ---"
        "`n - - -   A u d i t i n g   $($langFile.Name)   - - -" | Add-Content -LiteralPath $OutputPath

        $content = Get-Content -LiteralPath $langFile.FullName -Raw
        $keys = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

        $keySet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($key in $keys) {
            $keySet.Add($key) | Out-Null
        }

        $missing = @($enKeys | Where-Object { -not $keySet.Contains($_) })
        if ($missing.Count -gt 0) {
            $msg = "Missing keys (present in en.lua but not in $($langFile.Name)) [Count: $($missing.Count)]:"
            Write-Host $msg
            " $msg" | Add-Content -LiteralPath $OutputPath

            $shown = 0
            foreach ($entry in $missing) {
                if ($shown -lt 10) {
                    Write-Host "  $entry"
                    "     $entry" | Add-Content -LiteralPath $OutputPath
                }
                $shown++
            }

            if ($shown -gt 10) {
                Write-Host "  ... and $($shown - 10) more"
                "     . . .   a n d   $($shown - 10)   m o r e" | Add-Content -LiteralPath $OutputPath
            }
        }
        else {
            ' No missing keys.' | Add-Content -LiteralPath $OutputPath
        }
    }

    Write-AuditSection -Title '3. Auditing String Usage' -OutputPath $OutputPath
    $defined = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $used = Get-Content -LiteralPath $UsedPath

    $definedSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in $defined) { $definedSet.Add($item) | Out-Null }

    $usedSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in $used) { $usedSet.Add($item) | Out-Null }

    'Unused strings (defined in en.lua but not found in codebase):' | Add-Content -LiteralPath $OutputPath
    $unused = @($defined | Where-Object { -not $usedSet.Contains($_) } | Sort-Object)
    foreach ($item in $unused) {
        " $item" | Add-Content -LiteralPath $OutputPath
    }

    "`n Missing strings (found in codebase but not in en.lua):" | Add-Content -LiteralPath $OutputPath
    $missingDefs = @($used | Where-Object { -not $definedSet.Contains($_) } | Sort-Object)
    foreach ($item in $missingDefs) {
        " $item" | Add-Content -LiteralPath $OutputPath
    }

    Write-AuditSection -Title '4. Auditing Untranslated Strings' -OutputPath $OutputPath
    $enPairs = [regex]::Matches($enContent, 'ZO_CreateStringId\("([^"]+)",\s*"(.*)"\)')
    $enMap = @{}
    foreach ($pair in $enPairs) {
        $enMap[$pair.Groups[1].Value] = $pair.Groups[2].Value
    }

    foreach ($langFile in $langs) {
        Write-Host "`n--- Checking $($langFile.Name) ---"
        "`n - - -   C h e c k i n g   $($langFile.Name)   - - -" | Add-Content -LiteralPath $OutputPath

        $content = Get-Content -LiteralPath $langFile.FullName -Raw
        $matches = [regex]::Matches($content, 'ZO_CreateStringId\("([^"]+)",\s*"(.*)"\)')

        $count = 0
        foreach ($match in $matches) {
            $key = $match.Groups[1].Value
            $value = $match.Groups[2].Value
            if ($enMap.ContainsKey($key) -and $value -eq $enMap[$key] -and $value.Length -gt 2) {
                $count++
            }
        }

        " Found $count potentially untranslated strings." | Add-Content -LiteralPath $OutputPath
    }

    Write-Host "`nAudit complete. Report saved to $OutputPath" -ForegroundColor Green
}

$context = Get-LangContext -RepositoryRoot $RootDir

switch ($Mode) {
    'Sync' {
        Invoke-LanguageSync -LangDir $context.LangDir -EnPath $context.EnPath
    }
    'Audit' {
        Invoke-LanguageAudit -RepositoryRoot $RootDir -LangDir $context.LangDir -EnPath $context.EnPath -OutputPath $ReportPath -UsedPath $UsedStringsPath
    }
    'SyncAndAudit' {
        Invoke-LanguageSync -LangDir $context.LangDir -EnPath $context.EnPath
        Invoke-LanguageAudit -RepositoryRoot $RootDir -LangDir $context.LangDir -EnPath $context.EnPath -OutputPath $ReportPath -UsedPath $UsedStringsPath
    }
}