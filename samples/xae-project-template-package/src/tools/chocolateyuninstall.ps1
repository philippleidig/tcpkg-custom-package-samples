# Script to delete the specified folder and all its contents

# Read the target folder path from the registry
$regPath = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
try {
    $regValue = Get-ItemProperty -Path $regPath -Name "InstallDir" -ErrorAction Stop
    $installFolder = $regValue.InstallDir
    $targetPath = Join-Path -Path $installFolder -ChildPath "Components\Base\PrjTemplate\Custom"
}
catch {
    Write-Error "Failed to read registry key 'InstallDir' from '$regPath': $_"
    exit 1
}

# Start deletion operation
Write-Host "Starting deletion operation..."

# Check if the target folder exists
if (-not (Test-Path -Path $targetPath)) {
    Write-Host "The target folder '$targetPath' does not exist. No action needed."
    exit 0
}

# Delete the target folder and all its contents
try {
    Write-Host "Deleting folder '$targetPath' and all its contents..."
    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
    Write-Host "Folder '$targetPath' deleted successfully."
}
catch {
    Write-Error "Error during deletion operation: $_"
    exit 1
}

# Verify deletion
if (-not (Test-Path -Path $targetPath)) {
    Write-Host "Verified: Folder '$targetPath' no longer exists."
}
else {
    Write-Warning "Folder '$targetPath' still exists after deletion attempt."
}

# Completion message
Write-Host "Script execution completed."