# =============================================================================
# TcXaeShell Settings Package - Installation Script
# =============================================================================
# This script imports Visual Studio settings into TcXaeShell IDE
# It is designed to be run in the context of a TcPkg/Chocolatey package.
# =============================================================================

# Define settings file name
$settingsFileName = "General.vssettings"

# Get the path to the settings file
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$settingsFile = Join-Path $toolsDir $settingsFileName

# Validate settings file exists
if (-not (Test-Path $settingsFile)) {
    Write-Error "Settings file not found: $settingsFile"
    exit 1
}

# Define TcXaeShell executable path
$tcxaeshellPath = "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe"

# Validate TcXaeShell is installed
if (-not (Test-Path $tcxaeshellPath)) {
    Write-Error "TcXaeShell not found at: $tcxaeshellPath"
    Write-Error "Please ensure TwinCAT XAE Shell is installed."
    exit 1
}

# Build the import command
$importArgs = "/command `"Tools.ImportandExportSettings /import:$settingsFile`""

Write-Host "Importing Visual Studio settings into TcXaeShell..."
Write-Host "Settings file: $settingsFile"

# Execute the import
try {
    $process = Start-Process -FilePath $tcxaeshellPath -ArgumentList $importArgs -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "Settings imported successfully."
    } else {
        Write-Warning "TcXaeShell exited with code: $($process.ExitCode)"
        Write-Warning "Settings may have been partially applied."
    }
} catch {
    Write-Error "Failed to import settings: $_"
    exit 1
}

Write-Host "TcXaeShell Settings installation complete."
