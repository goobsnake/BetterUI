$files = Get-ChildItem "$PSScriptRoot/../lang/*.lua" -Exclude "en.lua"
foreach ($file in $files) {
    Write-Host "Processing $($file.Name)..."
    (Get-Content $file.FullName) -replace 'SI_SAVE_EQUIP', 'SI_BETTERUI_SAVE_EQUIP' | 
    Where-Object { $_ -notmatch 'SI_BETTERUI_CURRENCY_LIMIT_REACHED' -and $_ -notmatch 'SI_BETTERUI_RESOURCE_ORB_FRAMES_ENABLED' } | 
    Set-Content $file.FullName
}
Write-Host "Done."
