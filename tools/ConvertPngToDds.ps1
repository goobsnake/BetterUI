# ConvertPngToDds.ps1
# Converts PNG files to DDS format for Elder Scrolls Online
# Requires texconv.exe from DirectXTex: https://github.com/microsoft/DirectXTex/releases
#
# ESO Supported DDS Formats:
#   - DXT1 (BC1): Best for images WITHOUT alpha/transparency (smallest file size)
#   - DXT3 (BC2): For images with sharp alpha transitions
#   - DXT5 (BC3): Best for images WITH alpha/transparency (smooth gradients) - RECOMMENDED
#   - B8G8R8A8 (BGRA): Uncompressed, highest quality but larger files
#
# NOTE: ESO requires power-of-2 texture dimensions (64, 128, 256, 512, 1024, etc.)
#       Use -ResizePow2 to automatically resize non-compliant images.

param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path to PNG file or directory containing PNG files")]
    [string]$InputPath,
    
    [Parameter(Mandatory = $false, HelpMessage = "DDS compression format: DXT1, DXT3, DXT5 (default), or BGRA")]
    [ValidateSet("DXT1", "DXT3", "DXT5", "BGRA")]
    [string]$Format = "DXT5",
    
    [Parameter(Mandatory = $false, HelpMessage = "Output directory (defaults to same as input)")]
    [string]$OutputDir,
    
    [Parameter(Mandatory = $false, HelpMessage = "Generate mipmaps")]
    [switch]$GenerateMipmaps,
    
    [Parameter(Mandatory = $false, HelpMessage = "Resize to nearest power-of-2 dimensions (REQUIRED for ESO)")]
    [switch]$ResizePow2,
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to texconv.exe (auto-detected if in PATH or same directory)")]
    [string]$TexconvPath
)

# --- Configuration ---
$ErrorActionPreference = "Stop"

# --- Find texconv.exe ---
function Find-Texconv {
    # Check if provided
    if ($TexconvPath -and (Test-Path $TexconvPath)) {
        return $TexconvPath
    }
    
    # Check same directory as script
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $localPath = Join-Path $scriptDir "texconv.exe"
    if (Test-Path $localPath) {
        return $localPath
    }
    
    # Check PATH
    $inPath = Get-Command "texconv.exe" -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }
    
    # Check common locations
    $commonPaths = @(
        "$env:USERPROFILE\Downloads\texconv.exe",
        "$env:USERPROFILE\Desktop\texconv.exe",
        "C:\Tools\texconv.exe",
        "C:\DirectXTex\texconv.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# --- Map format to texconv arguments ---
function Get-FormatArgs {
    param([string]$Format)
    
    # Use SRGB formats to preserve color accuracy (matching other project textures)
    switch ($Format) {
        "DXT1" { return @("-f", "BC1_UNORM_SRGB") }
        "DXT3" { return @("-f", "BC2_UNORM_SRGB") }
        "DXT5" { return @("-f", "BC3_UNORM_SRGB") }
        "BGRA" { return @("-f", "B8G8R8A8_UNORM_SRGB") }
        default { return @("-f", "BC3_UNORM_SRGB") }  # Default to DXT5
    }
}

# --- Convert a single file ---
function Convert-PngToDds {
    param(
        [string]$InputFile,
        [string]$OutputDirectory,
        [string]$TexconvExe,
        [string]$Format,
        [bool]$Mipmaps,
        [bool]$Pow2Resize
    )
    
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outputFile = Join-Path $OutputDirectory "$fileName.dds"
    
    # Build arguments
    $args = @()
    $args += Get-FormatArgs -Format $Format
    $args += "-o", $OutputDirectory
    $args += "-y"  # Overwrite existing
    
    if (-not $Mipmaps) {
        $args += "-m", "1"  # No mipmaps (single level)
    }
    
    # Resize to power-of-2 if requested (required for ESO)
    if ($Pow2Resize) {
        $args += "-pow2"
        Write-Host "  Resizing to power-of-2 dimensions" -ForegroundColor Gray
    }
    
    # Preserve straight alpha (non-premultiplied) for ESO compatibility
    # Do NOT use -pmalpha as it darkens semi-transparent pixels
    
    $args += $InputFile
    
    Write-Host "Converting: $InputFile -> $outputFile" -ForegroundColor Cyan
    Write-Host "  Format: $Format" -ForegroundColor Gray
    
    $process = Start-Process -FilePath $TexconvExe -ArgumentList $args -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "  Success!" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  Failed! Exit code: $($process.ExitCode)" -ForegroundColor Red
        return $false
    }
}

# --- Main Script ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  PNG to DDS Converter for ESO" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Find texconv
$texconv = Find-Texconv
if (-not $texconv) {
    Write-Host "ERROR: texconv.exe not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download texconv.exe from:" -ForegroundColor Yellow
    Write-Host "  https://github.com/microsoft/DirectXTex/releases" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Download the 'texconv.exe' standalone executable and either:" -ForegroundColor Gray
    Write-Host "  1. Place it in the same directory as this script" -ForegroundColor Gray
    Write-Host "  2. Add its location to your PATH" -ForegroundColor Gray
    Write-Host "  3. Use the -TexconvPath parameter" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "Using texconv: $texconv" -ForegroundColor Gray
Write-Host ""

# Validate input path
if (-not (Test-Path $InputPath)) {
    Write-Host "ERROR: Input path does not exist: $InputPath" -ForegroundColor Red
    exit 1
}

# Determine output directory
if (-not $OutputDir) {
    if (Test-Path $InputPath -PathType Container) {
        $OutputDir = $InputPath
    }
    else {
        $OutputDir = Split-Path -Parent $InputPath
    }
}

# Create output directory if needed
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Get files to convert
$files = @()
if (Test-Path $InputPath -PathType Container) {
    $files = Get-ChildItem -Path $InputPath -Filter "*.png" -File
    Write-Host "Found $($files.Count) PNG file(s) in directory" -ForegroundColor Gray
}
else {
    $files = @(Get-Item $InputPath)
}

if ($files.Count -eq 0) {
    Write-Host "No PNG files found to convert." -ForegroundColor Yellow
    exit 0
}

# Convert each file
$successCount = 0
$failCount = 0

foreach ($file in $files) {
    $result = Convert-PngToDds -InputFile $file.FullName -OutputDirectory $OutputDir -TexconvExe $texconv -Format $Format -Mipmaps $GenerateMipmaps -Pow2Resize $ResizePow2
    if ($result) {
        $successCount++
    }
    else {
        $failCount++
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Conversion Complete" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Successful: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount" -ForegroundColor Red
}
Write-Host "  Output: $OutputDir" -ForegroundColor Gray
Write-Host ""
