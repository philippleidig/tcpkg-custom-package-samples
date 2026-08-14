# Lifecycle scripts

TcPkg builds on the Chocolatey installation model, so a package's behaviour is defined by
PowerShell scripts in the package's `tools` folder. They are discovered **by name**, not by
configuration.

---

## The hooks

| Script | Trigger | Runs from |
| --- | --- | --- |
| `chocolateyinstall.ps1` | `tcpkg install`, and as part of `tcpkg upgrade` | the **new** package |
| `chocolateybeforemodify.ps1` | `tcpkg upgrade`, `tcpkg uninstall` | the **currently installed** package |
| `chocolateyuninstall.ps1` | `tcpkg uninstall` | the **currently installed** package |

All scripts:

- run **elevated** (the Package Manager requires administrator rights),
- run **non-interactively** — never prompt, never call `Read-Host`, never block on a dialog,
- are executed from the extracted package folder, whose path is not predictable.

### Execution order

**Fresh install**

```
extract package → chocolateyinstall.ps1
```

**Upgrade from 1.0.0 to 1.1.0**

```
chocolateybeforemodify.ps1 (from 1.0.0)  →  extract 1.1.0  →  chocolateyinstall.ps1 (from 1.1.0)
```

Note that `chocolateyuninstall.ps1` of the old version is **not** called during an upgrade. If the
old version must clean something up before the new one is deployed, that logic belongs in
`chocolateybeforemodify.ps1`.

**Uninstall**

```
chocolateybeforemodify.ps1  →  chocolateyuninstall.ps1
```

### What belongs where

| Task | Script |
| --- | --- |
| Copy payload to its destination | `chocolateyinstall.ps1` |
| Register a library, template, or component with a tool | `chocolateyinstall.ps1` |
| Write registry keys / environment variables | `chocolateyinstall.ps1` |
| Stop a service or the TwinCAT runtime before replacing files | `chocolateybeforemodify.ps1` |
| Flush a cache that would otherwise serve stale content | `chocolateybeforemodify.ps1` |
| Back up user state before overwriting it | `chocolateybeforemodify.ps1` |
| Remove deployed files | `chocolateyuninstall.ps1` |
| Unregister a library or component | `chocolateyuninstall.ps1` |

An empty hook file is valid. The boot project sample ships an empty
`chocolateybeforemodify.ps1` because it has nothing to prepare.

---

## Core idioms

### 1. Locate the payload relative to the script

The package is extracted to a versioned path under the Package Manager's working directory, so the
only reliable anchor is the script's own location:

```powershell
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fileLocation = Join-Path $toolsDir "MyCustomLibraryPlcProject.library"

if (-not (Test-Path $fileLocation)) {
    Write-Error "Payload not found: $fileLocation"
    exit 1
}
```

`$MyInvocation.MyCommand.Definition` resolves to the full path of the running `.ps1`, so
`$toolsDir` is always the `tools` folder inside the extracted package.

### 2. Locate TwinCAT through the registry

Never hard-code `C:\TwinCAT`. TwinCAT can be installed to a different drive, and the boot folder is
configurable independently of the install root.

```powershell
# Machine-wide, 64-bit OS -> WOW6432Node
$regPath = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"

$installDir = (Get-ItemProperty -Path $regPath -Name "InstallDir").InstallDir   # e.g. C:\TwinCAT\3.1\
$bootDir    = (Get-ItemProperty -Path $regPath -Name "BootDir").BootDir         # e.g. C:\TwinCAT\3.1\Boot\
```

```powershell
# Per-user engineering root, used by the PLC tooling
$tcBasePath = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Beckhoff\TwinCAT3" -Name "TwinCATDir").TwinCATDir
```

| Value | Hive | Typical content | Used for |
| --- | --- | --- | --- |
| `InstallDir` | `HKLM` | `C:\TwinCAT\3.1\` | Components, project templates |
| `BootDir` | `HKLM` | `C:\TwinCAT\3.1\Boot\` | Boot projects |
| `TwinCATDir` | `HKCU` | `C:\TwinCAT\` | PLC tooling such as `RepTool.exe` |

Always wrap registry reads in `try`/`catch` — on a machine without TwinCAT the key simply does not
exist, and a clear error is far more useful than a null-reference further down:

```powershell
try {
    $installFolder = (Get-ItemProperty -Path $regPath -Name "InstallDir" -ErrorAction Stop).InstallDir
}
catch {
    Write-Error "Failed to read 'InstallDir' from '$regPath': $_"
    exit 1
}
```

### 3. Fail loudly

TcPkg decides whether an installation succeeded from the exit code. A script that swallows errors
produces a package that reports success while having done nothing:

```powershell
try {
    Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
}
catch {
    Write-Error "Copy failed: $_"
    exit 1
}
```

Use `Write-Warning` for conditions that are recoverable (a backup could not be created) and
`Write-Error` + `exit 1` for conditions that mean the package is not installed.

### 4. Make install idempotent

`chocolateyinstall.ps1` runs on upgrades too, so it must tolerate a destination that already
exists. The project template sample removes the destination folder before recreating it, which
guarantees that files deleted from a newer template version do not linger:

```powershell
if (Test-Path -Path $destinationPath) {
    Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction Stop
}
New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
```

### 5. Make uninstall specific

An uninstall script must remove **what the package deployed** and nothing else. Enumerate the
payload and delete matching items in the destination rather than clearing the whole target folder:

```powershell
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$payloadRoot = Join-Path $toolsDir "TwinCAT RT (x64)"

Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($payloadRoot.Length).TrimStart('\')
    $target   = Join-Path $bootFolder $relative
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
    }
}
```

Deleting everything under a shared destination (`Get-ChildItem $bootFolder -Recurse | Remove-Item`)
will also remove content that other packages or the user placed there.

---

## Calling TwinCAT tooling

Some artefacts cannot simply be copied — they must be registered with a TwinCAT tool.

### `RepTool.exe` — PLC library repository

Used by the [PLC library sample](../samples/plc-library-package). It lives inside a
build-specific folder, so it has to be discovered:

```powershell
$searchPattern    = Join-Path $tcBasePath "3.1\Components\Plc\Build_4026.*\Common\RepTool.exe"
$RepToolLocations = @(Get-Item $searchPattern -ErrorAction SilentlyContinue | Sort-Object FullName)

if ($RepToolLocations.Count -eq 0) {
    Write-Error "RepTool.exe not found in expected TwinCAT directories."
    exit 1
}

# Highest build number wins
$RepToolLocation = $RepToolLocations[-1].FullName

# Derive the PLC profile name from the path: "Build_4026.x.y"
$plcProfile = $RepToolLocation.Substring($RepToolLocation.IndexOf("Build_4026."))
$plcProfile = $plcProfile.Substring(0, $plcProfile.IndexOf("\Common\RepTool.exe"))
```

| Argument | Purpose |
| --- | --- |
| `--profile="TwinCAT PLC Control_Build_4026.x.y"` | Selects the library repository profile. |
| `--installLib "<path>.library"` | Installs a library. |
| `--uninstallLib "<Name>, <Version> (<Vendor>)"` | Removes a library by its repository identifier. |

```powershell
Start-Process $RepToolLocation -ArgumentList @(
    "--profile=`"TwinCAT PLC Control_$plcProfile`"",
    "--installLib `"$fileLocation`""
) -Wait
```

> The uninstall identifier `Name, Version (Vendor)` comes from the library project's
> **Project Information**, not from the `.nuspec`. If they drift apart, the library cannot be
> uninstalled. See the sample README for the mapping.

### `TcXaeShell.exe /command` — IDE automation

Used by the [XAE Shell settings sample](../samples/xae-shell-settings-package). The IDE exposes
Visual Studio's command system on the command line:

```powershell
$tcxaeshellPath = "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe"

# Import
Start-Process -FilePath $tcxaeshellPath -Wait -PassThru -ArgumentList `
    "/command `"Tools.ImportandExportSettings /import:$settingsFile`""

# Export (backup)
Start-Process -FilePath $tcxaeshellPath -Wait -PassThru -ArgumentList `
    "/command `"Tools.ImportandExportSettings /export:$backupFile`""
```

Always pass `-Wait` so the hook does not return before the IDE has finished, and check
`$process.ExitCode`.

### Managed library cache

The PLC engineering environment caches library metadata. A stale cache can make a freshly
installed version invisible, so the library sample clears it in `chocolateybeforemodify.ps1`:

```powershell
$manLibPath = Join-Path $env:ALLUSERSPROFILE 'Beckhoff\TwinCAT\PlcEngineering\Managed Libraries'

if (Test-Path -Path $manLibPath) {
    Get-ChildItem -Path $manLibPath -Filter 'cache*' -Recurse -File |
        ForEach-Object { Remove-Item -Path $_.FullName -Force }
}
```

---

## Testing hooks without packing

The hooks are ordinary scripts. Run them directly from an elevated PowerShell session with the
working directory arranged like the extracted package:

```powershell
cd .\samples\plc-library-package\src
Copy-Item .\MyCustomLibraryPlcProject.library .\tools\   # mimic the <files> mapping
.\tools\chocolateyinstall.ps1
```

This is much faster than the pack → publish → install loop and gives you a real stack trace.

For an end-to-end test, pack into a scratch feed and install from it:

```powershell
.\build\pack.ps1 -Sample plc-library-package -OutputDirectory C:\ScratchFeed
tcpkg source add -n "Scratch" -s "C:\ScratchFeed"
tcpkg config unset -n VerifySignatures
tcpkg install MyCustomLibraryPackage
tcpkg uninstall MyCustomLibraryPackage
```

---

## Checklist

- [ ] Payload path derived from `$MyInvocation.MyCommand.Definition`, never hard-coded
- [ ] TwinCAT paths read from the registry, wrapped in `try`/`catch`
- [ ] `Test-Path` guard before every copy or external tool call
- [ ] `Write-Error` + `exit 1` on unrecoverable failure
- [ ] Install script is idempotent (safe to run over an existing installation)
- [ ] Uninstall removes only the package's own files
- [ ] Version-dependent values in the uninstall script kept in sync with the `.nuspec`
- [ ] No interactive prompts, no `pause`, no `Read-Host`
- [ ] Tested on a machine where TwinCAT is **not** installed to the default path

---

## See also

- [`nuspec-reference.md`](nuspec-reference.md) — how the scripts get into the package
- [`build-and-publish.md`](build-and-publish.md) — packing and distribution
- [Chocolatey helper reference](https://docs.chocolatey.org/en-us/create/functions/) — additional
  helper functions available inside the hooks
