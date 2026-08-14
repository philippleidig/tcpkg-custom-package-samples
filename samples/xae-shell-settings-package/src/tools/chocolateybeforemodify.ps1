# =============================================================================
# TcXaeShell Settings Package - Before Modify Script
# =============================================================================
# This script runs before package modification (upgrade/reinstall).
# It backs up the current Visual Studio settings.
# =============================================================================

# Define backup location
$backupDir = Join-Path $env:LOCALAPPDATA "TcXaeShellSettingsBackup"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $backupDir "backup_$timestamp.vssettings"

# Create backup directory if it doesn't exist
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# Define TcXaeShell executable path
$tcxaeshellPath = "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe"

# Check if TcXaeShell is installed
if (-not (Test-Path $tcxaeshellPath)) {
    Write-Warning "TcXaeShell not found. Cannot create settings backup."
    exit 0
}

Write-Host "Creating backup of current TcXaeShell settings..."
Write-Host "Backup location: $backupFile"

# Build the export command
$exportArgs = "/command `"Tools.ImportandExportSettings /export:$backupFile`""

try {
    $process = Start-Process -FilePath $tcxaeshellPath -ArgumentList $exportArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Warning "TcXaeShell exited with code: $($process.ExitCode) while exporting the settings."
    }

    if (Test-Path $backupFile) {
        Write-Host "Settings backup created successfully."
    } else {
        Write-Warning "Backup file was not created. Proceeding without backup."
    }
} catch {
    Write-Warning "Failed to create settings backup: $_"
    Write-Warning "Proceeding without backup."
}
