$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# Removes the boot project that this package deployed.
#
# Only files that are part of this package's payload are deleted. The boot
# folder is shared with the TwinCAT runtime and may contain content from other
# packages or from the user, so clearing it wholesale is never safe.
# ------------------------------------------------------------------------------

$bootProjectFolder = "TwinCAT RT (x64)"

$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$payloadRoot = Join-Path $toolsDir $bootProjectFolder

if (-not (Test-Path -LiteralPath $payloadRoot)) {
    Write-Warning "Payload folder not found: $payloadRoot. Nothing to remove."
    exit 0
}

# Resolve the runtime boot directory from the registry
$regPath = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
try {
    $bootFolder = (Get-ItemProperty -Path $regPath -Name "BootDir" -ErrorAction Stop).BootDir
}
catch {
    Write-Error "Failed to read registry value 'BootDir' from '$regPath': $_"
    exit 1
}

if (-not (Test-Path -LiteralPath $bootFolder)) {
    Write-Warning "Boot directory '$bootFolder' does not exist. Nothing to remove."
    exit 0
}

Write-Host "Removing boot project from '$bootFolder'..."

$payloadRootLength = $payloadRoot.TrimEnd('\').Length + 1

# 1. Remove the deployed files
Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($payloadRootLength)
    $targetPath   = Join-Path $bootFolder $relativePath

    if (Test-Path -LiteralPath $targetPath) {
        try {
            Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
            Write-Host "  removed $relativePath"
        }
        catch {
            Write-Warning "  failed to remove '$targetPath': $_"
        }
    }
}

# 2. Remove directories the package created, deepest first, but only if empty
Get-ChildItem -LiteralPath $payloadRoot -Recurse -Directory |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($payloadRootLength)
        $targetPath   = Join-Path $bootFolder $relativePath

        if (Test-Path -LiteralPath $targetPath) {
            if (-not (Get-ChildItem -LiteralPath $targetPath -Force)) {
                try {
                    Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                    Write-Host "  removed directory $relativePath"
                }
                catch {
                    Write-Warning "  failed to remove directory '$targetPath': $_"
                }
            }
            else {
                Write-Host "  keeping non-empty directory $relativePath"
            }
        }
    }

Write-Host "Boot project removed. Restart the TwinCAT runtime for the change to take effect."
