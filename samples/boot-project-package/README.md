# Boot project package

Deploys a complete TwinCAT boot project — system configuration plus compiled PLC application — into
the boot directory of a TwinCAT runtime, so a controller starts with a known application after a
reboot.

| | |
| --- | --- |
| **Package ID** | `MachineTypeABC` |
| **Variant** | `VariantXAR` — runtime systems |
| **Target** | `BootDir` from the registry, typically `C:\TwinCAT\3.1\Boot` |
| **Mechanism** | File copy |
| **Origin** | Consolidated from [`tcpkg-custom-boot-project-package`](https://github.com/philippleidig/tcpkg-custom-boot-project-package) |

---

## What the package does

On install it copies the contents of `tools\TwinCAT RT (x64)\` into the runtime's boot directory,
overwriting whatever is there. After a restart of the TwinCAT runtime in **Run** mode, the
controller executes the shipped application.

On uninstall it removes exactly the files the package deployed, leaving any other content in the
boot directory untouched.

## When to use it

- **Commissioning a series machine.** Every controller of *Machine Type ABC* gets the identical,
  released application by installing one package.
- **Field updates.** Roll out a new application version to installed machines through your feed
  instead of connecting XAE to each device.
- **Reproducible test benches.** Pin the exact application a test rig runs and switch between
  versions with `tcpkg install --version`.
- **Runtime images without engineering.** The target needs only XAR and the Package Manager — no
  TwinCAT XAE, no source project.

---

## ⚠️ Safety notes

This package writes directly into the boot directory of a TwinCAT runtime. Read this before
installing on anything that moves.

- **It replaces the machine's application.** Installing on the wrong controller means that
  controller will run a foreign application after the next start.
- **Bring the runtime into config mode first.** The runtime reads the boot folder at start-up.
  Replacing files while the application is running leads to a state where the running program and
  the boot folder disagree, and file locks may make the copy fail.
- **Restart the runtime to activate.** The change takes effect only after the TwinCAT runtime is
  restarted in Run mode.
- **`Port_851.autostart` is part of the payload.** Its presence makes the PLC application start
  automatically. That is usually what you want for a machine, and never what you want on a
  developer laptop.
- **Test on a bench system first.** Always.

---

## Contents

```
boot-project-package/
├── README.md
└── src/                                          # Everything here goes into the .nupkg
    ├── MachineTypeABC.nuspec                      # Package manifest
    ├── PackageIcon.png                            # Icon shown in the Package Manager UI
    └── tools/
        ├── chocolateyinstall.ps1                  # Copies the boot project into BootDir
        ├── chocolateyuninstall.ps1                # Removes the deployed files from BootDir
        ├── chocolateybeforemodify.ps1             # Empty - nothing to prepare
        ├── LICENSE.txt
        ├── VERIFICATION.txt
        └── TwinCAT RT (x64)/                      # The boot project payload
            ├── CurrentConfig.xml                  # System configuration
            ├── CurrentConfig.tszip                # Compressed system configuration
            ├── CurrentConfig/
            │   └── Untitled1.tpzip                # Archived engineering project
            └── Plc/
                ├── Port_851.app                   # Compiled PLC application
                ├── Port_851_boot.tizip            # PLC boot information
                ├── Port_851.autostart             # Enables autostart of the application
                ├── Port_851.cid                   # Compile / configuration identifier
                ├── Port_851.crc                   # Application checksum
                ├── Port_851.occ                   # Online change context
                ├── Port_851.oce                   # Online change entries
                └── Port_851.ocm                   # Online change map
```

The folder name `TwinCAT RT (x64)` mirrors the naming XAE uses for the runtime target. Its
*contents* — not the folder itself — are copied into `BootDir`.

---

## How it works

### `chocolateyinstall.ps1`

```powershell
$bootProjectFolder = "TwinCAT RT (x64)"

$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fileLocation = Join-Path $toolsDir $bootProjectFolder

$regPath   = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
$bootFolder = (Get-ItemProperty -Path $regPath -Name "BootDir").BootDir

Copy-Item -Path "$fileLocation\*" -Destination "$bootFolder" -Recurse -Force -Verbose
```

`BootDir` is read from the registry rather than assumed, because it is configurable and does not
have to sit under the TwinCAT install directory.

### `chocolateyuninstall.ps1`

Enumerates the payload and removes only the matching files from `BootDir`, then removes the
directories it created if they ended up empty:

```powershell
$payloadRootLength = $payloadRoot.TrimEnd('\').Length + 1

Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($payloadRootLength)
    $targetPath   = Join-Path $bootFolder $relativePath
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Force
    }
}
```

> The boot directory is shared with the TwinCAT runtime and possibly with other packages, so a
> blanket `Get-ChildItem $bootFolder -Recurse | Remove-Item` would destroy unrelated content.
> Uninstall scripts should always be scoped to their own payload.

### `chocolateybeforemodify.ps1`

Empty. The payload is plain files that the install script overwrites; nothing has to be released or
backed up first. If your own package needs to switch the runtime to config mode before the files
are replaced, that logic belongs here.

---

## Building

```powershell
# From the repository root
.\build\pack.ps1 -Sample boot-project-package

# Or directly
tcpkg pack "samples\boot-project-package\src\MachineTypeABC.nuspec" -o "C:\LocalFeed"
```

## Installing

On the **target runtime**, in an elevated shell:

```powershell
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"   # once per machine
tcpkg config unset -n VerifySignatures                   # once, dev machines only
tcpkg install MachineTypeABC
```

Then restart the TwinCAT runtime in **Run** mode to start the boot project.

## Uninstalling

```powershell
tcpkg uninstall MachineTypeABC
```

Restart the runtime afterwards.

---

## Adapting it to your own boot project

1. **Produce the boot project.** In TwinCAT XAE, activate the configuration on the target (or on a
   local runtime). TwinCAT writes the boot folder to `BootDir`, typically
   `C:\TwinCAT\3.1\Boot`.

2. **Copy the boot folder into the package.** Replace the contents of
   `src/tools/TwinCAT RT (x64)/` with your `Boot` directory contents.

   > Check what you are about to ship. `CurrentConfig.xml` contains the full system configuration
   > including AMS Net IDs and routes. Remove anything machine-specific or confidential.

3. **Decide about autostart.** Keep `Port_851.autostart` if the PLC application should start
   automatically; delete it otherwise.

4. **Update the manifest** — `<id>`, `<version>`, `<title>`, `<authors>`, `<description>`, and the
   `Category` tag. Keep `VariantXAR` so the package is only offered on runtime systems.

5. **Update `LICENSE.txt` and `VERIFICATION.txt`** to list your files.

6. **Pack and test on a bench system**, including the uninstall.

### Releasing a new version

```powershell
# 1. Re-activate the configuration in XAE and copy the new Boot folder into src\tools\TwinCAT RT (x64)\
# 2. Bump the manifest
.\build\set-version.ps1 -Sample boot-project-package -Version 1.2.11
# 3. Repack
.\build\pack.ps1 -Sample boot-project-package -OutputDirectory C:\LocalFeed
```

Old files that no longer exist in the new boot project are **not** removed by the install script,
because it copies rather than mirrors. If your boot project changes structurally — for example the
PLC moves from port 851 to 852 — uninstall the old package version before installing the new one.

### Multiple PLC runtimes

A boot project with several PLC runtimes contains one file set per port
(`Port_851.*`, `Port_852.*`, …). No script changes are needed — copy the whole `Plc` folder and the
payload-scoped uninstall handles it automatically.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Failed to read registry value 'BootDir'` | TwinCAT runtime not installed, or a 32-bit OS (no `WOW6432Node`) | Verify `HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1` exists |
| Copy fails with "access denied" | Shell not elevated, or the runtime holds the files | Run as Administrator and switch TwinCAT to config mode first |
| Application does not start after reboot | `Port_851.autostart` missing, or the runtime is in config mode | Include the `.autostart` file and start the runtime in Run mode |
| Runtime starts the *old* application | Runtime not restarted since the install | Restart the TwinCAT runtime |
| Runtime reports a configuration error | Boot project built for a different TwinCAT version or hardware | Rebuild the boot project against the target's TwinCAT version and I/O configuration |

---

## See also

- [`docs/lifecycle-scripts.md`](../../docs/lifecycle-scripts.md) — registry lookups and payload-scoped uninstall
- [`docs/nuspec-reference.md`](../../docs/nuspec-reference.md) — the `VariantXAR` tag
- [`docs/build-and-publish.md`](../../docs/build-and-publish.md) — feeds and rollout
