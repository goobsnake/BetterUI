<#
.SYNOPSIS
Converts PNG (and optionally DDS) textures to ESO-compatible DDS output.

.DESCRIPTION
Wraps `texconv.exe` to batch-convert textures using ESO-friendly defaults.
Supports BC1/BC2/BC3 (DXT1/DXT3/DXT5) and BGRA output formats.

.PARAMETER InputPath
Path to a texture file or a directory containing textures.

.PARAMETER Format
DDS output format. Defaults to DXT5.

.PARAMETER OutputDir
Output directory for converted files. Defaults to input directory.

.PARAMETER SkipMipmaps
If set, outputs a single mip level.

.PARAMETER ResizePow2
If set, applies texconv `-pow2` resize. ESO textures should use power-of-two dimensions.

.PARAMETER TexconvPath
Optional explicit path to `texconv.exe`.

.PARAMETER Profile
Optional named profile. `ResourceOrbFrames` enforces required filenames with 1024x1024 source PNGs,
automatically resizing each to the target dimensions defined in Get-ResourceOrbFramesProfileSpec.

.EXAMPLE
.\ConvertPngToDds.ps1 -InputPath '.\Modules\CIM\Textures' -Format DXT5 -ResizePow2

.EXAMPLE
.\ConvertPngToDds.ps1 -InputPath '.\foo.png' -OutputDir '.\out' -SkipMipmaps

.EXAMPLE
.\ConvertPngToDds.ps1 -InputPath '.\Modules\ResourceOrbFrames\CustomTextures' -Profile ResourceOrbFrames -Format DXT5
#>
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Path to PNG/DDS file or directory containing files')]
    [string]$InputPath,

    [Parameter(HelpMessage = 'DDS compression format: DXT1, DXT3, DXT5 (default), or BGRA')]
    [ValidateSet('DXT1', 'DXT3', 'DXT5', 'BGRA')]
    [string]$Format = 'DXT5',

    [Parameter(HelpMessage = 'Output directory (defaults to same as input)')]
    [string]$OutputDir,

    [Parameter(HelpMessage = 'Skip generating mipmaps')]
    [switch]$SkipMipmaps,

    [Parameter(HelpMessage = 'Resize to nearest power-of-2 dimensions')]
    [switch]$ResizePow2,

    [Parameter(HelpMessage = 'Optional conversion profile: ResourceOrbFrames enforces 1024x1024 sources and resizes to per-texture target dimensions')]
    [ValidateSet('None', 'ResourceOrbFrames')]
    [string]$Profile = 'None',

    [Parameter(HelpMessage = 'Path to texconv.exe (auto-detected if in PATH or same directory)')]
    [string]$TexconvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-Texconv {
    if ($TexconvPath -and (Test-Path -LiteralPath $TexconvPath -PathType Leaf)) {
        return $TexconvPath
    }

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $localPath = Join-Path $scriptDir 'texconv.exe'
    if (Test-Path -LiteralPath $localPath -PathType Leaf) {
        return $localPath
    }

    $inPath = Get-Command 'texconv.exe' -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }

    $commonPaths = @(
        "$env:USERPROFILE\Downloads\texconv.exe",
        "$env:USERPROFILE\Desktop\texconv.exe",
        'C:\Tools\texconv.exe',
        'C:\DirectXTex\texconv.exe'
    )

    foreach ($path in $commonPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return $null
}

function Get-FormatArgs {
    param([string]$SelectedFormat)

    switch ($SelectedFormat) {
        'DXT1' { return @('-f', 'BC1_UNORM') }
        'DXT3' { return @('-f', 'BC2_UNORM') }
        'DXT5' { return @('-f', 'BC3_UNORM') }
        'BGRA' { return @('-f', 'B8G8R8A8_UNORM') }
        default { return @('-f', 'BC3_UNORM') }
    }
}

function Get-ResourceOrbFramesProfileSpec {
    # Source PNGs are 1024x1024. Each texture is resized to its target dimensions below.
    return [ordered]@{
        'Bar'               = @{ Width = 512; Height = 512 }
        'CastBar'           = @{ Width = 512; Height = 512 }
        'MountBar'          = @{ Width = 512; Height = 512 }
        'OrbBorder'         = @{ Width = 512; Height = 512 }
        'OrbFill'           = @{ Width = 512; Height = 512 }
        'OrbOverlay_Shield' = @{ Width = 512; Height = 512 }
        'OrbSplitter'       = @{ Width = 512; Height = 512 }
        'OrnamentLeft'      = @{ Width = 512; Height = 512 }
        'OrnamentRight'     = @{ Width = 512; Height = 512 }
    }
}

function Test-IsPowerOfTwo {
    param([int]$Value)

    if ($Value -lt 1) {
        return $false
    }

    return (($Value -band ($Value - 1)) -eq 0)
}

function Test-IsBlockCompatibleDimension {
    param([int]$Value)

    return ($Value -gt 0) -and (($Value % 4) -eq 0)
}

function Select-PreferredProfileCandidate {
    param(
        [object[]]$Candidates,
        [string]$LogicalName,
        [string]$Label
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) {
        return $null
    }

    if ($Candidates.Count -eq 1) {
        return $Candidates[0]
    }

    $sorted = @($Candidates | Sort-Object @{
            Expression = { $_.FullName.Length }
        }, @{
            Expression = { $_.FullName.ToLowerInvariant() }
        })

    $selected = $sorted[0]
    $ignoredCount = $sorted.Count - 1
    Write-Host "Profile warning: found $($sorted.Count) $Label sources for '$LogicalName'. Using '$($selected.FullName)' and ignoring $ignoredCount duplicate(s)." -ForegroundColor DarkYellow
    return $selected
}

function Get-PngDimensions {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 24) {
        return $null
    }

    $pngSig = @([byte]0x89, [byte]0x50, [byte]0x4E, [byte]0x47, [byte]0x0D, [byte]0x0A, [byte]0x1A, [byte]0x0A)
    for ($i = 0; $i -lt $pngSig.Length; $i++) {
        if ($bytes[$i] -ne $pngSig[$i]) {
            return $null
        }
    }

    $widthBytes = [byte[]]$bytes[16..19]
    $heightBytes = [byte[]]$bytes[20..23]
    [array]::Reverse($widthBytes)
    [array]::Reverse($heightBytes)

    return @{
        Width  = [int][BitConverter]::ToUInt32($widthBytes, 0)
        Height = [int][BitConverter]::ToUInt32($heightBytes, 0)
        Type   = 'PNG'
    }
}

function Get-DdsDimensions {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 128) {
        return $null
    }

    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 3)
    if ($magic -ne 'DDS') {
        return $null
    }

    return @{
        Width  = [int][BitConverter]::ToUInt32($bytes, 16)
        Height = [int][BitConverter]::ToUInt32($bytes, 12)
        Type   = 'DDS'
    }
}

function Get-TextureDimensions {
    param([string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path)
    if (-not $ext) {
        return $null
    }

    switch ($ext.ToLowerInvariant()) {
        '.png' { return Get-PngDimensions -Path $Path }
        '.dds' { return Get-DdsDimensions -Path $Path }
        default { return $null }
    }
}

function Resolve-ResourceOrbFramesProfileFiles {
    param(
        [string]$InputDirectory,
        [hashtable]$ProfileSpec
    )

    $baseSize = 1024
    $allFiles = Get-ChildItem -LiteralPath $InputDirectory -Include '*.png', '*.dds' -Recurse -File
    if ($allFiles.Count -eq 0) {
        Write-Host 'ERROR: No PNG/DDS files found for ResourceOrbFrames profile.' -ForegroundColor Red
        return $null
    }

    $resolved = @()
    $errors = @()

    foreach ($logicalName in $ProfileSpec.Keys) {
        $target = $ProfileSpec[$logicalName]
        $candidates = @($allFiles | Where-Object { $_.BaseName -ieq $logicalName })

        if ($candidates.Count -eq 0) {
            $errors += "Missing required file: $logicalName.png or $logicalName.dds"
            continue
        }

        $pngCandidates = @($candidates | Where-Object { $_.Extension -ieq '.png' })
        $ddsCandidates = @($candidates | Where-Object { $_.Extension -ieq '.dds' })

        $selected = $null
        $selectedPng = Select-PreferredProfileCandidate -Candidates $pngCandidates -LogicalName $logicalName -Label 'PNG'
        $selectedDds = Select-PreferredProfileCandidate -Candidates $ddsCandidates -LogicalName $logicalName -Label 'DDS'

        if ($selectedPng) {
            $selected = $selectedPng
            if ($selectedDds) {
                Write-Host "Profile note: using PNG for '$logicalName' and ignoring DDS source." -ForegroundColor DarkYellow
            }
        }
        elseif ($selectedDds) {
            $selected = $selectedDds
        }

        if (-not $selected) {
            $errors += "Unable to resolve source for '$logicalName'."
            continue
        }

        $dims = Get-TextureDimensions -Path $selected.FullName
        if (-not $dims) {
            $errors += "Could not read dimensions for '$($selected.FullName)'."
            continue
        }

        if (($dims.Width -ne $baseSize) -or ($dims.Height -ne $baseSize)) {
            $errors += "$logicalName source size mismatch: got $($dims.Width)x$($dims.Height), expected ${baseSize}x${baseSize}."
            continue
        }

        Write-Host "  OK: $logicalName ${baseSize}x${baseSize} -> $($target.Width)x$($target.Height)" -ForegroundColor Gray

        $resolved += [PSCustomObject]@{
            LogicalName  = $logicalName
            File         = $selected
            Width        = $dims.Width
            Height       = $dims.Height
            TargetWidth  = $target.Width
            TargetHeight = $target.Height
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            Write-Host "ERROR: $err" -ForegroundColor Red
        }
        return $null
    }

    return @($resolved)
}

function Validate-ProfileOutputDimensions {
    param(
        [string]$OutputFile,
        [string]$LogicalName,
        [hashtable]$ProfileSpec
    )

    $expected = $ProfileSpec[$LogicalName]
    if (-not $expected) {
        Write-Host "  ERROR: No profile spec found for '$LogicalName'." -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
        Write-Host "  ERROR: Expected output not found: $OutputFile" -ForegroundColor Red
        return $false
    }

    $dims = Get-TextureDimensions -Path $OutputFile
    if (-not $dims) {
        Write-Host "  ERROR: Could not read output dimensions: $OutputFile" -ForegroundColor Red
        return $false
    }

    if (($dims.Width -ne $expected.Width) -or ($dims.Height -ne $expected.Height)) {
        Write-Host "  ERROR: Output size for '$LogicalName' is $($dims.Width)x$($dims.Height); expected $($expected.Width)x$($expected.Height)." -ForegroundColor Red
        return $false
    }

    return $true
}

function Convert-TextureToDds {
    param(
        [string]$InputFile,
        [string]$OutputDirectory,
        [string]$TexconvExe,
        [string]$SelectedFormat,
        [bool]$DisableMipmaps,
        [bool]$Pow2Resize,
        [int]$TargetWidth = 0,
        [int]$TargetHeight = 0
    )

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outputFile = Join-Path $OutputDirectory "$fileName.dds"

    $args = @()
    $args += Get-FormatArgs -SelectedFormat $SelectedFormat
    $args += '-o', $OutputDirectory
    $args += '-y'
    $args += '-if', 'CUBIC'
    $args += '--ignore-srgb'

    if ($DisableMipmaps) {
        $args += '-m', '1'
    }

    if ($TargetWidth -gt 0 -and $TargetHeight -gt 0) {
        $args += '-w', $TargetWidth.ToString()
        $args += '-h', $TargetHeight.ToString()
        Write-Host "  Resizing: 1024x1024 -> ${TargetWidth}x${TargetHeight}" -ForegroundColor Gray
    }
    elseif ($Pow2Resize) {
        $args += '-pow2'
        Write-Host '  Resizing to power-of-2 dimensions' -ForegroundColor Gray
    }

    $args += $InputFile

    Write-Host "Converting: $InputFile -> $outputFile" -ForegroundColor Cyan
    Write-Host "  Format: $SelectedFormat" -ForegroundColor Gray

    $process = Start-Process -FilePath $TexconvExe -ArgumentList $args -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Host '  Success!' -ForegroundColor Green
        return $true
    }

    Write-Host "  Failed! Exit code: $($process.ExitCode)" -ForegroundColor Red
    return $false
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Yellow
Write-Host '  Texture to DDS Converter for ESO' -ForegroundColor Yellow
Write-Host '========================================' -ForegroundColor Yellow
Write-Host ''

$texconv = Find-Texconv
if (-not $texconv) {
    Write-Host 'ERROR: texconv.exe not found!' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Please download texconv.exe from:' -ForegroundColor Yellow
    Write-Host '  https://github.com/microsoft/DirectXTex/releases' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Download the standalone executable and either:" -ForegroundColor Gray
    Write-Host '  1. Place it in the same directory as this script' -ForegroundColor Gray
    Write-Host '  2. Add its location to PATH' -ForegroundColor Gray
    Write-Host '  3. Use the -TexconvPath parameter' -ForegroundColor Gray
    Write-Host ''
    exit 1
}

Write-Host "Using texconv: $texconv" -ForegroundColor Gray
Write-Host ''

if (-not (Test-Path -LiteralPath $InputPath)) {
    Write-Host "ERROR: Input path does not exist: $InputPath" -ForegroundColor Red
    exit 1
}

if (-not $OutputDir) {
    if (Test-Path -LiteralPath $InputPath -PathType Container) {
        $OutputDir = $InputPath
    }
    else {
        $OutputDir = Split-Path -Parent $InputPath
    }
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$files = @()
$profileSpec = $null
$profileResolvedByName = @{}

if ($Profile -eq 'ResourceOrbFrames') {
    if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
        Write-Host 'ERROR: -Profile ResourceOrbFrames requires InputPath to be a directory containing the full texture set.' -ForegroundColor Red
        exit 1
    }

    if ($Format -ne 'DXT5') {
        Write-Host "WARNING: ResourceOrbFrames profile is tuned for DXT5. Current format: $Format" -ForegroundColor Yellow
    }

    $profileSpec = Get-ResourceOrbFramesProfileSpec
    Write-Host "Profile: ResourceOrbFrames ($($profileSpec.Count) required files; 1024x1024 base -> per-texture target resize)" -ForegroundColor Cyan

    $resolved = Resolve-ResourceOrbFramesProfileFiles -InputDirectory $InputPath -ProfileSpec $profileSpec
    if (-not $resolved) {
        Write-Host 'Profile validation failed. No files were converted.' -ForegroundColor Red
        exit 1
    }

    foreach ($item in $resolved) {
        $profileResolvedByName[$item.LogicalName] = $item
    }

    $files = @($resolved | ForEach-Object { $_.File })
}
else {
    if (Test-Path -LiteralPath $InputPath -PathType Container) {
        $files = Get-ChildItem -LiteralPath $InputPath -Include '*.png', '*.dds' -Recurse -File
        Write-Host "Found $($files.Count) texture file(s) in directory" -ForegroundColor Gray
    }
    else {
        $files = @(Get-Item -LiteralPath $InputPath)
    }
}

if ($files.Count -eq 0) {
    Write-Host 'No texture files found to convert.' -ForegroundColor Yellow
    exit 0
}

$successCount = 0
$failCount = 0

foreach ($file in $files) {
    $targetW = 0
    $targetH = 0
    if ($Profile -eq 'ResourceOrbFrames') {
        $logicalName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $sourceInfo = $profileResolvedByName[$logicalName]
        if ($sourceInfo) {
            $targetW = $sourceInfo.TargetWidth
            $targetH = $sourceInfo.TargetHeight
        }
    }

    $result = Convert-TextureToDds `
        -InputFile $file.FullName `
        -OutputDirectory $OutputDir `
        -TexconvExe $texconv `
        -SelectedFormat $Format `
        -DisableMipmaps $SkipMipmaps `
        -Pow2Resize $ResizePow2 `
        -TargetWidth $targetW `
        -TargetHeight $targetH

    if ($result -and $Profile -eq 'ResourceOrbFrames') {
        $outputFile = Join-Path $OutputDir "$logicalName.dds"
        if (-not $sourceInfo) {
            Write-Host "  ERROR: Missing resolved profile metadata for '$logicalName'." -ForegroundColor Red
            $result = $false
        }
        else {
            $result = Validate-ProfileOutputDimensions `
                -OutputFile $outputFile `
                -LogicalName $logicalName `
                -ProfileSpec $profileSpec
        }
    }

    if ($result) {
        $successCount++
    }
    else {
        $failCount++
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Yellow
Write-Host '  Conversion Complete' -ForegroundColor Yellow
Write-Host '========================================' -ForegroundColor Yellow
Write-Host "  Successful: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount" -ForegroundColor Red
}
Write-Host "  Output: $OutputDir" -ForegroundColor Gray
Write-Host ''
