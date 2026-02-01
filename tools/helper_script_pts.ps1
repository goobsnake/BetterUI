# Get the current script's directory
$sourceDir = 'X:\Git\BetterUI'

$destDir = "$env:USERPROFILE\Documents\Elder Scrolls Online\pts\AddOns\BetterUI\"

# Remove destination directory if it exists, then recreate it
if (Test-Path $destDir) {
    Remove-Item -Path $destDir -Recurse -Force
}
New-Item -ItemType Directory -Path $destDir -Force | Out-Null

# Define files and directories to exclude (matches .gitignore plus standard exclusions)
$excludeItems = @(
    '.git',
    '.gitignore',
    '.idea',
    '.images',
    'esoui',
    'tmp',
    '.vscode',
    'README.md',
    'tools',
    '.venv',
    'Source',
    'LICENSE.md',
    'docs',
    '.agent'
)

# Copy items while excluding specified files/directories
Get-ChildItem -Path $sourceDir -Exclude $excludeItems |
Where-Object { $_.Name -notin $excludeItems } |
ForEach-Object {
    $destination = Join-Path $destDir $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Path $_.FullName -Destination $destination -Recurse -Force
    }
    else {
        Copy-Item -Path $_.FullName -Destination $destination -Force
    }
}

Write-Host "Files copied successfully to: $destDir"