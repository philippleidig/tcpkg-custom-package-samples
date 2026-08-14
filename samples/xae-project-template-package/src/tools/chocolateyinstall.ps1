# Script to copy the content of a folder including all subfolders and files, overwriting existing files and folders

# Determine the source folder path relative to the script's location in the 'tools' folder
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourcePath = Join-Path -Path $toolsDir -ChildPath "Custom TwinCAT Project"

# Read the destination path from the registry
$regPath = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
try {
    $regValue = Get-ItemProperty -Path $regPath -Name "InstallDir" -ErrorAction Stop
    $installFolder = $regValue.InstallDir
    $destinationPath = Join-Path -Path $installFolder -ChildPath "Components\Base\PrjTemplate\Custom"
}
catch {
    Write-Error "Failed to read registry key 'InstallDir' from '$regPath': $_"
    exit 1
}

if (-not (Test-Path -Path $sourcePath)) {
    Write-Error "The source folder '$sourcePath' does not exist!"
    exit 1
}

if (Test-Path -Path $destinationPath) {
    try {
        Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction Stop
        Write-Host "Existing destination folder '$destinationPath' removed."
    }
    catch {
        Write-Error "Failed to remove existing destination folder: $_"
        exit 1
    }
}

try {
    New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
    Write-Host "Destination folder '$destinationPath' created."
}
catch {
    Write-Error "Failed to create destination folder: $_"
    exit 1
}

try {
    Write-Host "Copying contents from '$sourcePath' to '$destinationPath'..."
    Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    
    Write-Host "Copy operation completed successfully."
    
    # Verify if all items were copied
    $sourceItems = Get-ChildItem -Path $sourcePath -Recurse
    $destinationItems = Get-ChildItem -Path $destinationPath -Recurse
    
    if ($sourceItems.Count -eq $destinationItems.Count) {
        Write-Host "All files and folders copied successfully."
    } else {
        Write-Warning "The number of copied items does not match the source folder."
        Write-Host "Source: $($sourceItems.Count) items, Destination: $($destinationItems.Count) items"
    }
}
catch {
    Write-Error "Error during copy operation: $_"
    exit 1
}

Write-Host "Script execution completed."