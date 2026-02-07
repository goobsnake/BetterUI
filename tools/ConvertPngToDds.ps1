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

.EXAMPLE
.\ConvertPngToDds.ps1 -InputPath '.\Modules\CIM\Textures' -Format DXT5 -ResizePow2

.EXAMPLE
.\ConvertPngToDds.ps1 -InputPath '.\foo.png' -OutputDir '.\out' -SkipMipmaps
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

function Convert-TextureToDds {
    param(
        [string]$InputFile,
        [string]$OutputDirectory,
        [string]$TexconvExe,
        [string]$SelectedFormat,
        [bool]$DisableMipmaps,
        [bool]$Pow2Resize
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

    if ($Pow2Resize) {
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
if (Test-Path -LiteralPath $InputPath -PathType Container) {
    $files = Get-ChildItem -LiteralPath $InputPath -Include '*.png', '*.dds' -Recurse -File
    Write-Host "Found $($files.Count) texture file(s) in directory" -ForegroundColor Gray
}
else {
    $files = @(Get-Item -LiteralPath $InputPath)
}

if ($files.Count -eq 0) {
    Write-Host 'No texture files found to convert.' -ForegroundColor Yellow
    exit 0
}

$successCount = 0
$failCount = 0

foreach ($file in $files) {
    $result = Convert-TextureToDds `
        -InputFile $file.FullName `
        -OutputDirectory $OutputDir `
        -TexconvExe $texconv `
        -SelectedFormat $Format `
        -DisableMipmaps $SkipMipmaps `
        -Pow2Resize $ResizePow2

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