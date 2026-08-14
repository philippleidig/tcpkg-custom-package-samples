$bootProjectFolder = "TwinCAT RT (x64)"

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fileLocation = Join-Path $toolsDir $bootProjectFolder

$regPath = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
$regValue = Get-ItemProperty -Path $regPath -Name "BootDir"
$bootFolder = $regValue.BootDir

if (-not (Test-Path $fileLocation)) {
	Write-Error "Boot project not found: $fileLocation"
	exit 1
}

Copy-Item -Path "$fileLocation\*" -Destination "$bootFolder" -Recurse -Force -Verbose
