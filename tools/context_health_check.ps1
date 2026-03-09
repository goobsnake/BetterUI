param(
    [string]$ContinuityPath = "docs/planning/continuity-ledger.md",
    [string]$CoverageRegex = "^(Modules/|lang/|BetterUI\.lua$|BetterUI\.txt$|docs/planning/continuity-ledger\.md$)",
    [int]$DoneCap = 12,
    [int]$WorkingSetCap = 12,
    [int]$ReceiptsCap = 20,
    [switch]$Strict,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Path {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }
    return ($PathValue.Trim().Replace("\", "/"))
}

function Test-WorkingSetMatch {
    param(
        [string]$FilePath,
        [string]$WorkingSetEntry
    )

    $normalizedFile = Normalize-Path $FilePath
    $normalizedEntry = Normalize-Path ($WorkingSetEntry.Trim([char]96))

    if ([string]::IsNullOrWhiteSpace($normalizedEntry)) {
        return $false
    }

    if ($normalizedEntry.Contains("*") -or $normalizedEntry.Contains("?")) {
        return ($normalizedFile -like $normalizedEntry)
    }

    if ($normalizedFile -eq $normalizedEntry) {
        return $true
    }

    return $normalizedFile.StartsWith($normalizedEntry + "/")
}

if (-not (Test-Path -LiteralPath $ContinuityPath)) {
    throw "Continuity file not found: $ContinuityPath"
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$head = (git rev-parse --short HEAD).Trim()
$statusLines = @(git status --short | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$changedFiles = @(git diff --name-only HEAD | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Normalize-Path $_ })
$coverageChangedFiles = @($changedFiles | Where-Object { $_ -match $CoverageRegex })

$lines = Get-Content -LiteralPath $ContinuityPath

$doneCount = 0
$workingSetEntries = @()
$receiptsCount = 0
$hasNow = $false
$hasNext = $false
$hasOpenQuestions = $false

$inDone = $false
$inWorkingSet = $false
$inReceipts = $false

foreach ($line in $lines) {
    if ($line -match "^\*\*Now:\*\*") { $hasNow = $true }
    if ($line -match "^\*\*Next:\*\*") { $hasNext = $true }
    if ($line -match "^## Open Questions") { $hasOpenQuestions = $true }

    if ($line -match "^\*\*Done \(recent") {
        $inDone = $true
        continue
    }
    if ($inDone -and $line -match "^\*\*Now:\*\*") {
        $inDone = $false
    }
    if ($inDone -and $line -match "^\s*-\s+") {
        $doneCount++
    }

    if ($line -match "^## Working Set") {
        $inWorkingSet = $true
        continue
    }
    if ($inWorkingSet -and $line -match "^---") {
        $inWorkingSet = $false
    }
    if ($inWorkingSet -and $line -match '^\s*-\s+`(.+?)`') {
        $workingSetEntries += $Matches[1]
        continue
    }
    if ($inWorkingSet -and $line -match "^\s*-\s+(.+)$") {
        $workingSetEntries += $Matches[1].Trim()
    }

    if ($line -match "^## Receipts") {
        $inReceipts = $true
        continue
    }
    if ($inReceipts -and $line -match "^---") {
        $inReceipts = $false
    }
    if ($inReceipts -and $line -match "^\|\s*20\d\d-\d\d-\d\d\s*\|") {
        $receiptsCount++
    }
}

$uncoveredChanged = @()
foreach ($file in $coverageChangedFiles) {
    $covered = $false
    foreach ($entry in $workingSetEntries) {
        if (Test-WorkingSetMatch -FilePath $file -WorkingSetEntry $entry) {
            $covered = $true
            break
        }
    }
    if (-not $covered) {
        $uncoveredChanged += $file
    }
}

$warnings = @()
if ($doneCount -gt $DoneCap) {
    $warnings += "Done count exceeds cap ($doneCount > $DoneCap)."
}
if ($workingSetEntries.Count -gt $WorkingSetCap) {
    $warnings += "Working set count exceeds cap ($($workingSetEntries.Count) > $WorkingSetCap)."
}
if ($receiptsCount -gt $ReceiptsCap) {
    $warnings += "Receipts count exceeds cap ($receiptsCount > $ReceiptsCap)."
}
if (-not $hasNow) {
    $warnings += "Continuity missing **Now** section."
}
if (-not $hasNext) {
    $warnings += "Continuity missing **Next** section."
}
if (-not $hasOpenQuestions) {
    $warnings += "Continuity missing Open Questions section."
}
if ($coverageChangedFiles.Count -gt 0 -and $uncoveredChanged.Count -gt 0) {
    $warnings += "Coverage-scope changed files not represented in Working Set: $($uncoveredChanged.Count)."
}

$status = if ($warnings.Count -eq 0) { "PASS" } else { "WARN" }

$result = [ordered]@{
    status = $status
    branch = $branch
    head = $head
    statusEntryCount = $statusLines.Count
    changedFileCount = $changedFiles.Count
    coverageChangedFileCount = $coverageChangedFiles.Count
    doneCount = $doneCount
    doneCap = $DoneCap
    workingSetCount = $workingSetEntries.Count
    workingSetCap = $WorkingSetCap
    receiptsCount = $receiptsCount
    receiptsCap = $ReceiptsCap
    uncoveredChangedFiles = $uncoveredChanged
    warnings = $warnings
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host "[context-health] Status: $status"
    Write-Host "[context-health] Branch: $branch"
    Write-Host "[context-health] HEAD: $head"
    Write-Host "[context-health] Working tree entries: $($statusLines.Count)"
    Write-Host "[context-health] Changed files: $($changedFiles.Count)"
    Write-Host "[context-health] Coverage-scope changed files: $($coverageChangedFiles.Count)"
    Write-Host "[context-health] Continuity counts: Done=$doneCount/$DoneCap, WorkingSet=$($workingSetEntries.Count)/$WorkingSetCap, Receipts=$receiptsCount/$ReceiptsCap"
    if ($warnings.Count -gt 0) {
        Write-Host "[context-health] Warnings:"
        foreach ($warning in $warnings) {
            Write-Host "  - $warning"
        }
    }
}

if ($Strict -and $warnings.Count -gt 0) {
    exit 2
}

exit 0
