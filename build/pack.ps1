<#
.SYNOPSIS
    Packs one or all TcPkg sample packages in this repository into .nupkg files.

.DESCRIPTION
    Discovers every sample under samples/<name>/src/*.nuspec and packs it using
    'tcpkg pack'. If tcpkg is not available on PATH the script falls back to
    'nuget pack', which produces an equivalent package and allows builds on
    agents without a TwinCAT installation.

.PARAMETER Sample
    Name of a single sample folder under samples/ (e.g. 'plc-library-package').
    Omit to pack every sample.

.PARAMETER OutputDirectory
    Target directory for the generated .nupkg files. Defaults to '<repo>/dist'.

.PARAMETER Version
    Overrides the <version> from the .nuspec for this build only. The .nuspec
    file on disk is not modified. Use build/set-version.ps1 for a permanent change.

.PARAMETER Packer
    Force a specific packer: 'tcpkg' or 'nuget'. Defaults to 'auto'.

.EXAMPLE
    .\build\pack.ps1
    Packs every sample into .\dist

.EXAMPLE
    .\build\pack.ps1 -Sample plc-library-package -OutputDirectory C:\LocalFeed
    Packs a single sample straight into a local feed folder.

.EXAMPLE
    .\build\pack.ps1 -Version 1.4.0
    Packs every sample as version 1.4.0 without touching the .nuspec files.
#>
[CmdletBinding()]
param(
    [string]$Sample,
    [string]$OutputDirectory,
    [string]$Version,
    [ValidateSet('auto', 'tcpkg', 'nuget')]
    [string]$Packer = 'auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$samplesDir = Join-Path $repoRoot 'samples'

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot 'dist'
}

if ($Version -and $Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-]+)?$') {
    throw "Invalid version '$Version'. Expected semantic version, e.g. 1.2.3 or 1.2.3-beta1."
}

function Resolve-Packer {
    param([string]$Preference)

    $hasTcpkg = [bool](Get-Command 'tcpkg' -ErrorAction SilentlyContinue)
    $hasNuget = [bool](Get-Command 'nuget' -ErrorAction SilentlyContinue)

    switch ($Preference) {
        'tcpkg' {
            if (-not $hasTcpkg) { throw "tcpkg was requested but is not available on PATH. Install the TwinCAT Package Manager." }
            return 'tcpkg'
        }
        'nuget' {
            if (-not $hasNuget) { throw "nuget was requested but is not available on PATH. See https://www.nuget.org/downloads" }
            return 'nuget'
        }
        default {
            if ($hasTcpkg) { return 'tcpkg' }
            if ($hasNuget) {
                Write-Warning "tcpkg not found on PATH - falling back to 'nuget pack'."
                return 'nuget'
            }
            throw "Neither 'tcpkg' nor 'nuget' was found on PATH. Install the TwinCAT Package Manager or the NuGet CLI."
        }
    }
}

function Get-SampleNuspec {
    param([System.IO.DirectoryInfo]$SampleDir)

    $srcDir = Join-Path $SampleDir.FullName 'src'
    if (-not (Test-Path -LiteralPath $srcDir)) { return $null }

    $nuspecs = @(Get-ChildItem -LiteralPath $srcDir -Filter '*.nuspec' -File)

    if ($nuspecs.Count -eq 0) {
        Write-Warning "No .nuspec found in '$srcDir' - skipping sample '$($SampleDir.Name)'."
        return $null
    }
    if ($nuspecs.Count -gt 1) {
        throw "Sample '$($SampleDir.Name)' contains $($nuspecs.Count) .nuspec files. Exactly one is expected."
    }

    return $nuspecs[0]
}

if (-not (Test-Path -LiteralPath $samplesDir)) {
    throw "Samples directory not found: $samplesDir"
}

$sampleDirs = if ($Sample) {
    $candidate = Join-Path $samplesDir $Sample
    if (-not (Test-Path -LiteralPath $candidate)) {
        $available = (Get-ChildItem -LiteralPath $samplesDir -Directory | Select-Object -ExpandProperty Name) -join ', '
        throw "Sample '$Sample' not found. Available samples: $available"
    }
    @(Get-Item -LiteralPath $candidate)
} else {
    @(Get-ChildItem -LiteralPath $samplesDir -Directory | Sort-Object Name)
}

$tool = Resolve-Packer -Preference $Packer
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path

Write-Host "Packer          : $tool"
Write-Host "Output directory: $resolvedOutput"
if ($Version) { Write-Host "Version override: $Version" }
Write-Host ''

$succeeded = @()
$failed    = @()

foreach ($sampleDir in $sampleDirs) {
    $nuspec = Get-SampleNuspec -SampleDir $sampleDir
    if (-not $nuspec) { continue }

    Write-Host "==> $($sampleDir.Name) ($($nuspec.Name))"

    $arguments = switch ($tool) {
        'tcpkg' {
            $a = @('pack', $nuspec.FullName, '-o', $resolvedOutput)
            if ($Version) { $a += @('--version', $Version) }
            $a
        }
        'nuget' {
            $a = @('pack', $nuspec.FullName, '-OutputDirectory', $resolvedOutput, '-NoDefaultExcludes', '-NonInteractive')
            if ($Version) { $a += @('-Version', $Version) }
            $a
        }
    }

    & $tool @arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Packing '$($sampleDir.Name)' failed with exit code $LASTEXITCODE."
        $failed += $sampleDir.Name
    } else {
        $succeeded += $sampleDir.Name
    }
    Write-Host ''
}

Write-Host '--------------------------------------------------'
Write-Host "Packed : $($succeeded.Count) [$($succeeded -join ', ')]"
if ($failed.Count -gt 0) {
    Write-Host "Failed : $($failed.Count) [$($failed -join ', ')]"
}
Write-Host '--------------------------------------------------'

$packages = @(Get-ChildItem -LiteralPath $resolvedOutput -Filter '*.nupkg' -File | Sort-Object Name)
if ($packages.Count -gt 0) {
    Write-Host ''
    Write-Host 'Packages in output directory:'
    $packages | ForEach-Object { Write-Host "  $($_.Name)" }
}

if ($failed.Count -gt 0) { exit 1 }
