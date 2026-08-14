<#
.SYNOPSIS
    Sets or bumps the <version> element in a sample's .nuspec file.

.DESCRIPTION
    Updates the version of a single sample or of every sample in the repository.
    Either provide an explicit -Version, or use -BumpMajor / -BumpMinor / -BumpPatch
    to increment the current value. Any prerelease suffix is preserved when bumping.

.PARAMETER Sample
    Name of a sample folder under samples/ (e.g. 'plc-library-package').
    Omit to apply the change to every sample.

.PARAMETER Version
    Explicit semantic version to write, e.g. '1.3.0' or '1.3.0-beta1'.

.PARAMETER BumpMajor
    Increment the major version and reset minor and patch to 0.

.PARAMETER BumpMinor
    Increment the minor version and reset patch to 0.

.PARAMETER BumpPatch
    Increment the patch version.

.EXAMPLE
    .\build\set-version.ps1 -Sample plc-library-package -Version 1.3.0

.EXAMPLE
    .\build\set-version.ps1 -Sample plc-library-package -BumpPatch

.EXAMPLE
    .\build\set-version.ps1 -BumpMinor
    Bumps the minor version of every sample.

.NOTES
    Some samples encode their version in a lifecycle script as well - the PLC library
    sample identifies the library by "Name, Version (Vendor)" in chocolateyuninstall.ps1.
    This script warns when such an occurrence is detected so it can be updated too.
#>
[CmdletBinding(DefaultParameterSetName = 'Explicit')]
param(
    [string]$Sample,

    [Parameter(ParameterSetName = 'Explicit', Mandatory = $true)]
    [string]$Version,

    [Parameter(ParameterSetName = 'Major', Mandatory = $true)]
    [switch]$BumpMajor,

    [Parameter(ParameterSetName = 'Minor', Mandatory = $true)]
    [switch]$BumpMinor,

    [Parameter(ParameterSetName = 'Patch', Mandatory = $true)]
    [switch]$BumpPatch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$samplesDir = Join-Path $repoRoot 'samples'

$semVerPattern = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?<suffix>[-+][0-9A-Za-z.\-]+)?$'

if ($Version -and $Version -notmatch $semVerPattern) {
    throw "Invalid version '$Version'. Expected semantic version, e.g. 1.2.3 or 1.2.3-beta1."
}

function Get-NextVersion {
    param([string]$Current)

    if ($Current -notmatch $semVerPattern) {
        throw "Current version '$Current' is not a valid semantic version and cannot be bumped."
    }

    $major  = [int]$Matches['major']
    $minor  = [int]$Matches['minor']
    $patch  = [int]$Matches['patch']
    $suffix = if ($Matches['suffix']) { $Matches['suffix'] } else { '' }

    switch ($PSCmdlet.ParameterSetName) {
        'Major' { $major++; $minor = 0; $patch = 0 }
        'Minor' { $minor++; $patch = 0 }
        'Patch' { $patch++ }
    }

    return "$major.$minor.$patch$suffix"
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

foreach ($sampleDir in $sampleDirs) {
    $srcDir = Join-Path $sampleDir.FullName 'src'
    if (-not (Test-Path -LiteralPath $srcDir)) { continue }

    $nuspecs = @(Get-ChildItem -LiteralPath $srcDir -Filter '*.nuspec' -File)
    if ($nuspecs.Count -ne 1) {
        Write-Warning "Sample '$($sampleDir.Name)' does not contain exactly one .nuspec - skipping."
        continue
    }
    $nuspec = $nuspecs[0]

    $content = Get-Content -LiteralPath $nuspec.FullName -Raw -Encoding UTF8

    # Read the current version through the XML DOM so that <version> elements
    # appearing inside XML comments are ignored.
    try {
        $xml = [xml]$content
    }
    catch {
        Write-Warning "'$($nuspec.Name)' is not well-formed XML - skipping. $_"
        continue
    }

    $currentVersion = $xml.package.metadata.version
    if ([string]::IsNullOrWhiteSpace($currentVersion)) {
        Write-Warning "No <version> element found in '$($nuspec.Name)' - skipping."
        continue
    }
    $currentVersion = $currentVersion.Trim()

    if ($currentVersion -eq '$version$') {
        Write-Warning "'$($nuspec.Name)' uses the version token and is versioned at pack time - skipping."
        continue
    }

    $newVersion = if ($Version) { $Version } else { Get-NextVersion -Current $currentVersion }

    if ($newVersion -eq $currentVersion) {
        Write-Host "$($sampleDir.Name): already at $currentVersion"
        continue
    }

    # Locate the first <version> element that is not inside an XML comment.
    $commentSpans = [regex]::Matches($content, '<!--.*?-->', 'Singleline')
    $target = $null
    foreach ($match in [regex]::Matches($content, '<version>[^<]*</version>')) {
        $insideComment = $false
        foreach ($span in $commentSpans) {
            if ($match.Index -ge $span.Index -and $match.Index -lt ($span.Index + $span.Length)) {
                $insideComment = $true
                break
            }
        }
        if (-not $insideComment) {
            $target = $match
            break
        }
    }

    if (-not $target) {
        Write-Warning "Could not locate a writable <version> element in '$($nuspec.Name)' - skipping."
        continue
    }

    $updated = $content.Substring(0, $target.Index) +
               "<version>$newVersion</version>" +
               $content.Substring($target.Index + $target.Length)

    # Write the file back byte-for-byte apart from the version, preserving the
    # original byte-order-mark and trailing newline.
    $hasBom = $false
    $firstBytes = [System.IO.File]::ReadAllBytes($nuspec.FullName) | Select-Object -First 3
    if ($firstBytes.Count -eq 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) {
        $hasBom = $true
    }
    [System.IO.File]::WriteAllText($nuspec.FullName, $updated, [System.Text.UTF8Encoding]::new($hasBom))

    Write-Host "$($sampleDir.Name): $currentVersion -> $newVersion"

    # Warn about lifecycle scripts that embed the old version string.
    $toolsDir = Join-Path $srcDir 'tools'
    if (Test-Path -LiteralPath $toolsDir) {
        Get-ChildItem -LiteralPath $toolsDir -Filter '*.ps1' -File | ForEach-Object {
            $scriptContent = Get-Content -LiteralPath $_.FullName -Raw
            if ($scriptContent -and $scriptContent.Contains($currentVersion)) {
                Write-Warning "  '$($_.Name)' still references version '$currentVersion' - update it manually."
            }
        }
    }
}
