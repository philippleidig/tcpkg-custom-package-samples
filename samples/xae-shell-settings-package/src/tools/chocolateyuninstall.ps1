# =============================================================================
# TcXaeShell Settings Package - Uninstallation Script
# =============================================================================
# Visual Studio settings cannot be easily "uninstalled" once imported.
# This script notifies the user about manual settings reset options.
# =============================================================================

Write-Host "TcXaeShell Settings Package Uninstallation"
Write-Host "==========================================="
Write-Host ""
Write-Host "Note: Visual Studio settings cannot be automatically reverted."
Write-Host ""
Write-Host "To reset your TcXaeShell settings to defaults:"
Write-Host "1. Open TcXaeShell"
Write-Host "2. Go to Tools -> Import and Export Settings..."
Write-Host "3. Select 'Reset all settings'"
Write-Host "4. Follow the wizard to reset to default settings"
Write-Host ""
Write-Host "Alternatively, you can import a different settings file using:"
Write-Host "  TcXaeShell.exe /command `"Tools.ImportandExportSettings /import:<path>`""
Write-Host ""
Write-Host "Uninstallation complete. Settings remain applied until manually changed."