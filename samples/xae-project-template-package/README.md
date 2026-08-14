# XAE project template package

Adds a company-specific TwinCAT project template to the **New Project** dialog of TwinCAT XAE, so
every new project starts from an approved baseline instead of an empty solution.

| | |
| --- | --- |
| **Package ID** | `TwinCAT.XAE.ProjectTemplate` |
| **Variant** | `VariantXAE` — engineering systems |
| **Target** | `<InstallDir>\Components\Base\PrjTemplate\Custom` |
| **Mechanism** | File copy + `templates.vsdir` registration |
| **Origin** | Consolidated from [`tcpkg-custom-xae-project-template-package`](https://github.com/philippleidig/tcpkg-custom-xae-project-template-package) |

---

## What the package does

On install it copies the folder `tools\Custom TwinCAT Project\` into the TwinCAT project template
directory:

```
<InstallDir>\Components\Base\PrjTemplate\Custom
```

`<InstallDir>` is read from the registry, so it works regardless of where TwinCAT is installed.

The copied folder contains a `templates.vsdir` file, which is how Visual Studio — and therefore the
TwinCAT XAE Shell — discovers templates in a directory. After the next start of XAE, the template
appears under **File → New → Project** in the TwinCAT Projects category.

On uninstall the `Custom` folder is removed again.

## When to use it

- **Company standards.** Every new project starts with the agreed router memory, task
  configuration, folder structure, and naming conventions already in place.
- **Machine platforms.** A template per machine family, preconfigured with the right I/O skeleton
  and PLC structure.
- **Onboarding.** New engineers create a correct project without reading a setup guide.
- **Training and workshops.** Hand out a prepared starting point that everyone gets identically.

---

## Contents

```
xae-project-template-package/
└── src/                                             # Everything here goes into the .nupkg
    ├── TwinCATXaeProjectTemplate.nuspec              # Package manifest
    ├── PackageIcon.png                               # Icon shown in the Package Manager UI
    └── tools/
        ├── chocolateyinstall.ps1                     # Copies the template into the TwinCAT install dir
        ├── chocolateyuninstall.ps1                   # Removes the template folder
        ├── chocolateybeforemodify.ps1                # Re-deploys before upgrade/uninstall
        ├── LICENSE.txt
        ├── VERIFICATION.txt
        └── Custom TwinCAT Project/                   # The template payload
            ├── Custom TwinCAT Project.tsproj         # The project skeleton
            ├── Custom TwinCAT Project.ico            # Icon in the New Project dialog
            └── templates.vsdir                       # Registers the template with the dialog
```

---

## How it works

### `chocolateyinstall.ps1`

1. Resolves the payload relative to the script:
   ```powershell
   $toolsDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
   $sourcePath = Join-Path $toolsDir "Custom TwinCAT Project"
   ```
2. Reads the TwinCAT install directory from the registry:
   ```powershell
   $regPath      = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
   $installFolder = (Get-ItemProperty -Path $regPath -Name "InstallDir").InstallDir
   $destinationPath = Join-Path $installFolder "Components\Base\PrjTemplate\Custom"
   ```
3. **Removes** the destination folder if it exists, then recreates it. This makes the install
   idempotent and guarantees that files deleted from a newer template version do not survive an
   upgrade.
4. Copies the payload recursively and verifies that source and destination item counts match.

### `chocolateyuninstall.ps1`

Resolves the same destination and removes it recursively, then verifies the folder is gone.

### `chocolateybeforemodify.ps1`

Identical to the install script. It runs from the *old* package before an upgrade, which leaves the
template directory in a clean, known state before the new version is deployed.

---

## The `templates.vsdir` file

This is the piece that makes the template visible. It is a single pipe-delimited line:

```
Custom TwinCAT Project.tsproj|{3d3e7b23-b969-4a99-bfee-d0d953c182d4}|#127|20|#132|{3d3e7b23-b958-4a99-bfee-d0d953c182d4}|206|128|#133
```

| Position | Value in the sample | Meaning |
| --- | --- | --- |
| 1 | `Custom TwinCAT Project.tsproj` | Relative path to the template file |
| 2 | `{3d3e7b23-b969-…}` | Package GUID providing the localised resource strings |
| 3 | `#127` | Resource ID of the display name |
| 4 | `20` | Sort priority in the dialog (lower appears first) |
| 5 | `#132` | Resource ID of the description |
| 6 | `{3d3e7b23-b958-…}` | Package GUID providing the icon |
| 7 | `206` | Resource ID of the icon |
| 8 | `128` | Flags |
| 9 | `#133` | Suggested default project name |

Fields 3, 5, and 9 may also be literal strings instead of `#`-prefixed resource IDs, which is
easier when you do not have a resource DLL:

```
My Company Project.tsproj|{3d3e7b23-b969-4a99-bfee-d0d953c182d4}|My Company Project|10|Standard project for our machines|{3d3e7b23-b958-4a99-bfee-d0d953c182d4}|206|128|MyCompanyProject
```

> The GUIDs identify the TwinCAT project system. Keep them as they are — they are not
> package-specific.

---

## Building

```powershell
# From the repository root
.\build\pack.ps1 -Sample xae-project-template-package

# Or directly
tcpkg pack "samples\xae-project-template-package\src\TwinCATXaeProjectTemplate.nuspec" -o "C:\LocalFeed"
```

## Installing

```powershell
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"   # once per machine
tcpkg config unset -n VerifySignatures                   # once, dev machines only
tcpkg install TwinCAT.XAE.ProjectTemplate
```

Restart TwinCAT XAE Shell, then **File → New → Project → TwinCAT Projects**.

## Uninstalling

```powershell
tcpkg uninstall TwinCAT.XAE.ProjectTemplate
```

---

## Adapting it to your own template

1. **Build the reference project.** Create a TwinCAT project in XAE and configure everything you
   want as a default: router memory, task setup, PLC project skeleton, folder structure, I/O
   placeholders, library references.

2. **Reduce it to a template.** Copy the `.tsproj` into
   `src/tools/Custom TwinCAT Project/` and strip anything machine-specific — target NetIDs, absolute
   paths, license keys. The sample template is deliberately minimal:

   ```xml
   <TcSmProject ... TcVersionFixed="true">
     <Project ProjectGUID="{F62CA2C5-768D-42DC-A4C9-402F3C512875}"
              RelativeTargetNetId="true"
              RelativeIpAddresses="true"
              SaveSolutionArchive="true">
       <System>
         <Settings RouterMemory="134217728" MaxStackSize="512"/>
       </System>
       <Io AddIoDescToArchive="true" />
     </Project>
   </TcSmProject>
   ```

   `RelativeTargetNetId` and `RelativeIpAddresses` keep the template portable across machines.

3. **Rename the folder and update `templates.vsdir`.** The first field must match your `.tsproj`
   file name. Rename `src/tools/Custom TwinCAT Project/` to your template name and adjust
   `$sourcePath` in all three scripts:
   ```powershell
   $sourcePath = Join-Path $toolsDir "My Company Project"
   ```

4. **Replace the icon** (`.ico`) if you want your own branding in the dialog.

5. **Update the manifest** — `<id>`, `<version>`, `<title>`, `<authors>`, `<description>`, and the
   `Category` tag. Keep `VariantXAE`.

6. **Pack, install, and check the New Project dialog.** Then uninstall and check that the template
   disappears.

### Shipping several templates

Put each template in its own subfolder with its own `templates.vsdir`, and copy the parent folder:

```
tools/
└── Templates/
    ├── Machine Type A/
    │   ├── Machine Type A.tsproj
    │   └── templates.vsdir
    └── Machine Type B/
        ├── Machine Type B.tsproj
        └── templates.vsdir
```

Point `$sourcePath` at `Templates` and keep the destination at `…\PrjTemplate\Custom`.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Failed to read registry key 'InstallDir'` | TwinCAT not installed, or a 32-bit OS (no `WOW6432Node`) | Verify `HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1` exists |
| Install succeeds, template not in the dialog | XAE was not restarted, or `templates.vsdir` is missing | Restart XAE; confirm the file was copied to `…\PrjTemplate\Custom` |
| Template listed but fails to create a project | First field of `templates.vsdir` does not match the `.tsproj` file name | Correct the file name, including the extension |
| Template has no name or icon | Resource IDs (`#127`, `#132`) reference strings that do not exist | Use literal strings instead of `#`-prefixed IDs |
| "The number of copied items does not match" warning | Destination partially locked, e.g. XAE has the folder open | Close XAE and reinstall |
| Access denied during install | Shell not elevated — the target is under `%ProgramFiles%` | Run as Administrator |

---

## See also

- [`docs/lifecycle-scripts.md`](../../docs/lifecycle-scripts.md) — idempotent install and registry lookups
- [`docs/nuspec-reference.md`](../../docs/nuspec-reference.md) — packing a payload folder via `tools\**`
- [XAE Shell settings package](../xae-shell-settings-package) — standardising the IDE itself
