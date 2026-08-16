# TwinCAT Package Manager – Custom Package Samples

A collection of ready-to-build sample packages for the **Beckhoff TwinCAT Package Manager (`tcpkg`)**.

Each sample is a complete, self-contained custom package that demonstrates one realistic
deployment scenario — shipping a PLC library, rolling out a boot project, distributing an IDE
project template, standardising IDE settings, or bundling packages into a workload.

Together with the [documentation](#documentation) in this repository they are meant to be used as
a **starting point and reference** for building your own packages and your own internal package
feed.

---

## Table of contents

- [What is the TwinCAT Package Manager?](#what-is-the-twincat-package-manager)
- [Samples](#samples)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Anatomy of a TcPkg package](#anatomy-of-a-tcpkg-package)
  - [The `.nuspec` file](#the-nuspec-file)
  - [The `tools` folder and lifecycle scripts](#the-tools-folder-and-lifecycle-scripts)
  - [Payload files](#payload-files)
- [Building a package](#building-a-package)
- [Publishing to a feed](#publishing-to-a-feed)
- [Installing and uninstalling](#installing-and-uninstalling)
- [Versioning](#versioning)
- [Continuous integration](#continuous-integration)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## What is the TwinCAT Package Manager?

The TwinCAT Package Manager (`tcpkg`) is Beckhoff's delivery mechanism for TwinCAT 4026 and later.
It replaces the monolithic TwinCAT setup with a package-based installation model. Under the hood
it builds on the **NuGet package format** and the **Chocolatey** installation conventions, which is
why a TcPkg package is really just a `.nupkg` file containing:

- a `.nuspec` manifest describing the package, and
- a `tools` folder containing PowerShell lifecycle scripts plus the payload.

The important consequence: **anything Chocolatey can do, a TcPkg package can do.** You are not
limited to shipping Beckhoff components. You can ship your own libraries, configuration, project
templates, boot projects, documentation, or arbitrary tooling to every engineering station and
every controller in your organisation — from a feed you control.

`tcpkg` exposes this through the `tcpkg pack` command and through custom *sources* (feeds), which
can be a plain network share, a local folder, or a full NuGet server such as Azure Artifacts,
GitHub Packages, Artifactory, or ProGet.

> **Terminology:** a *package* contains files and installation logic. A *workload* is a
> meta-package that contains no payload of its own and only pulls in other packages through
> dependencies. See [`docs/workloads.md`](docs/workloads.md).

---

## Samples

| Sample | Package ID | Variant | What it does |
| --- | --- | --- | --- |
| [PLC library](samples/plc-library-package) | `MyCustomLibraryPackage` | XAE | Installs a compiled TwinCAT `.library` into the local PLC library repository using `RepTool.exe`. |
| [Boot project](samples/boot-project-package) | `MachineTypeABC` | XAR | Deploys a complete TwinCAT boot project (PLC application + configuration) into the runtime boot folder. |
| [XAE project template](samples/xae-project-template-package) | `TwinCAT.XAE.ProjectTemplate` | XAE | Adds a company-specific TwinCAT project template to the "New Project" dialog of the XAE Shell. |
| [XAE Shell settings](samples/xae-shell-settings-package) | `TcXaeShellSettings` | XAE | Imports a `.vssettings` file to standardise IDE layout, fonts, and editor behaviour. |
| [PLC library workload](samples/plc-library-workload) | `MyCustomLibraries.Workload` | XAE | Meta-package that installs a whole set of library packages with a single command. |

Every sample folder contains its own `README.md` explaining **what the package does**, **when to
use it**, **how it works internally**, and **how to build, install, and adapt it**.

---

## Prerequisites

| Requirement | Notes |
| --- | --- |
| **TwinCAT 4026** or newer | The Package Manager is part of TwinCAT 4026+. Older versions (4024 and earlier) use the classic setup and are not supported. |
| **TwinCAT Package Manager** | Install the *TwinCAT Package Manager (GUI) Setup* from the [Beckhoff download page](https://www.beckhoff.com/en-en/support/download-finder/software-and-tools/). Provides the `tcpkg` CLI. |
| **Administrator rights** | `tcpkg install` and the lifecycle scripts write to `%ProgramFiles%`, `HKLM`, and the TwinCAT boot folder. |
| **PowerShell 5.1+** | Used by the lifecycle scripts and the build scripts in `build/`. |
| **TwinCAT XAE** (engineering samples) | Required for the library, project template, and IDE settings samples. |
| **TwinCAT XAR** (runtime samples) | Required for the boot project sample. |

Check that the CLI is available:

```powershell
tcpkg --version
```

Installing the Package Manager unattended, e.g. on a build agent:

```powershell
Start-Process ".\TwinCAT-Package-Manager-GUI-Setup.exe" -NoNewWindow -Wait -ArgumentList @('/install','/quiet')
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
```

---

## Quick start

Build every sample in this repository into a local feed folder and install one of them:

```powershell
# 1. Pack all samples into .\dist
.\build\pack.ps1

# 2. Register the output folder as a package source (once per machine)
tcpkg source add -n "Local Samples" -s "$PWD\dist"

# 3. Allow unsigned packages (development machines only!)
tcpkg config unset -n VerifySignatures

# 4. Install a sample
tcpkg install MyCustomLibraryPackage
```

To build a single sample:

```powershell
.\build\pack.ps1 -Sample plc-library-package
```

---

## Anatomy of a TcPkg package

Every sample in this repository follows the same layout. Understanding it once is enough to build
any custom package:

```
samples/<sample-name>/
├── README.md                        # Sample-specific documentation
└── src/                             # Everything below src/ ends up in the .nupkg
    ├── <PackageId>.nuspec           # The package manifest
    ├── PackageIcon.png              # Icon shown in the Package Manager UI
    ├── <payload files>              # Optional payload next to the nuspec
    └── tools/
        ├── chocolateyinstall.ps1       # Runs on install
        ├── chocolateyuninstall.ps1     # Runs on uninstall
        ├── chocolateybeforemodify.ps1  # Runs before upgrade/uninstall of the *installed* version
        ├── LICENSE.txt                 # License of the shipped content
        ├── VERIFICATION.txt            # How a consumer can verify the payload
        └── <payload files>             # Payload copied into tools/
```

A `.nupkg` is just a ZIP archive — rename one to `.zip` to inspect exactly what was packed.

### The `.nuspec` file

The manifest is a standard NuGet `.nuspec` XML file. TcPkg adds meaning to a few of the fields.

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <!-- Required: unique within your feed. Also the name used by `tcpkg install <id>`. -->
    <id>MyCustomLibraryPackage</id>

    <!-- Required: semantic version major.minor.patch[-prerelease] -->
    <version>1.2.3</version>

    <!-- Optional: human-friendly display name -->
    <title>My Custom Library Package</title>

    <!-- Required: author or team -->
    <authors>Your Name</authors>

    <!-- Optional metadata -->
    <projectUrl>https://www.yourwebsite.com/</projectUrl>
    <copyright>(c) Your Name</copyright>
    <licenseUrl>https://www.yourwebsite.com/license</licenseUrl>
    <requireLicenseAcceptance>true</requireLicenseAcceptance>

    <!-- Required: PNG icon, referenced by its packed target name -->
    <icon>icon.png</icon>

    <!-- Required: space-separated tags. TcPkg reads these to place the package in the UI. -->
    <tags>CategoryMy&#160;Custom AllowMultipleVersions VariantXAE</tags>

    <!-- Required: shown in `tcpkg list` and in the UI -->
    <description>This is a custom package for delivering a library.</description>

    <!-- Optional: markdown supported -->
    <releaseNotes>Initial release.</releaseNotes>

    <!-- Optional: other packages that must be installed first -->
    <dependencies>
      <!-- <dependency id="OtherPackage" version="[1.0.0,2.0.0)" /> -->
    </dependencies>
  </metadata>

  <!-- Maps files from disk (src) into the package (target) -->
  <files>
    <file src="PackageIcon.png" target="icon.png" />
    <file src="tools\**" target="tools" />
    <file src="MyCustomLibraryPlcProject.library" target="tools\MyCustomLibraryPlcProject.library" />
  </files>
</package>
```

#### TcPkg-specific tags

The `<tags>` element is the main TcPkg extension point. Tags are **space separated**, and TcPkg
interprets the following prefixes:

| Tag | Effect |
| --- | --- |
| `Category<Name>` | Groups the package under *Name* in the Package Manager UI. The literal `Category` prefix is stripped for display. Use `&#160;` (non-breaking space) for multi-word names, e.g. `CategoryMy&#160;Custom` → **My Custom**. |
| `VariantXAE` | Package is only relevant for engineering systems. It is hidden from runtime-only (XAR) listings. |
| `VariantXAR` | Package is only relevant for runtime systems. It is hidden from engineering (XAE) listings. |
| `AllowMultipleVersions` | Several versions of the package may be installed side by side. Essential for PLC libraries, where projects may pin different versions. |
| `Workload` | Marks a meta-package. Used together with the `<packageTypes>` element below. |

#### Workload packages

A workload additionally requires the `packageTypes` element:

```xml
<packageTypes>
  <packageType name="Workload" />
</packageTypes>
```

Without it, TcPkg treats the package as a regular package and it will not appear under
`tcpkg list -t workload`. See [`docs/workloads.md`](docs/workloads.md).

#### The `<files>` section

`src` paths are relative to the folder containing the `.nuspec`; `target` paths are relative to the
package root. Two conventions matter:

- `<file src="PackageIcon.png" target="icon.png" />` — the file on disk may have any name, but the
  `<icon>` element must reference the **target** name.
- `<file src="tools\**" target="tools" />` — recursively packs the whole `tools` folder. This is
  what makes the lifecycle scripts discoverable.

Payload can either live inside `src/tools/` (packed automatically by the wildcard) or next to the
`.nuspec` with an explicit `target="tools\..."` mapping. Both approaches are used in this
repository; the explicit mapping keeps large binaries visually separate from the scripts.

Full field-by-field reference: [`docs/nuspec-reference.md`](docs/nuspec-reference.md).

### The `tools` folder and lifecycle scripts

TcPkg executes Chocolatey's lifecycle hooks. All of them are plain PowerShell, run **elevated**,
and run **non-interactively**.

| Script | When it runs | Typical use |
| --- | --- | --- |
| `chocolateyinstall.ps1` | After the package content has been extracted, on install **and** on upgrade. | Deploy the payload: copy files, call registration tools, write registry keys. |
| `chocolateyuninstall.ps1` | On `tcpkg uninstall`. | Undo what the install script did. |
| `chocolateybeforemodify.ps1` | Before an **already installed** version is upgraded or removed. Runs from the *old* package. | Stop services, back up state, flush caches, release file locks. |

Two idioms appear in every sample:

**1. Locate the payload relative to the script.** The package is extracted to a path you cannot
predict, so never hard-code it:

```powershell
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fileLocation = Join-Path $toolsDir "MyCustomLibraryPlcProject.library"
```

**2. Locate TwinCAT through the registry** instead of assuming `C:\TwinCAT`:

```powershell
# Machine-wide install root and boot folder (64-bit OS -> WOW6432Node)
$reg        = "HKLM:\SOFTWARE\WOW6432Node\Beckhoff\TwinCAT3\3.1"
$installDir = (Get-ItemProperty -Path $reg -Name "InstallDir").InstallDir
$bootDir    = (Get-ItemProperty -Path $reg -Name "BootDir").BootDir

# Per-user engineering root
$tcBasePath = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Beckhoff\TwinCAT3" -Name "TwinCATDir").TwinCATDir
```

Scripts should exit with a non-zero code on failure (`Write-Error` + `exit 1`) so that TcPkg marks
the installation as failed instead of silently continuing.

More detail and a decision guide: [`docs/lifecycle-scripts.md`](docs/lifecycle-scripts.md).

### Payload files

Two extra text files are conventional and expected by public feeds:

- **`LICENSE.txt`** — the license of the *content* you ship. Mandatory if the package contains
  redistributable third-party binaries.
- **`VERIFICATION.txt`** — explains how a consumer can independently verify that the payload is
  what it claims to be (checksums, origin, build instructions).

Neither is required for a purely internal feed, but including them keeps packages portable.

---

## Building a package

`tcpkg pack` turns a `.nuspec` and its referenced files into a `.nupkg`:

```powershell
tcpkg pack "samples\plc-library-package\src\MyCustomLibraryPackage.nuspec" -o "C:\LocalFeed"
```

This repository wraps that in a helper script that handles all samples, output folders, and
optional version overrides:

```powershell
# All samples -> .\dist
.\build\pack.ps1

# One sample, custom output folder
.\build\pack.ps1 -Sample boot-project-package -OutputDirectory C:\LocalFeed

# Override the version at pack time (useful in CI)
.\build\pack.ps1 -Version 1.4.0
```

The script falls back to `nuget pack` when `tcpkg` is not on the `PATH`, so packages can also be
built on a plain build agent without a TwinCAT installation.

To change the version stored in a `.nuspec` permanently:

```powershell
.\build\set-version.ps1 -Sample plc-library-package -Version 1.3.0
```

See [`docs/build-and-publish.md`](docs/build-and-publish.md) for the full workflow.

---

## Publishing to a feed

A *source* (feed) is where `tcpkg` looks for packages. The simplest one is a folder:

```powershell
# Register a folder or UNC share as a feed (once per machine)
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"
tcpkg source add -n "Company Feed"  -s "\\fileserver\twincat\feed"

# List configured sources
tcpkg source list

# Remove a source
tcpkg source remove -n "My Local Feed"
```

"Publishing" to a folder feed simply means copying the `.nupkg` into it — that is exactly what
`-o "C:\LocalFeed"` does. For a real NuGet server, push the artifact with `nuget push` or
`dotnet nuget push` and register the server URL as the source instead.

### Signature verification

Beckhoff's official feed is signed. Your own packages are not, so `tcpkg` will refuse them until
verification is turned off:

```powershell
tcpkg config unset -n VerifySignatures
```

> **⚠️ This is a global setting.** It disables signature checking for **all** feeds, including the
> official Beckhoff one. Only do this on development, test, and build machines where you
> understand the risk. For production rollouts, sign your packages and leave verification enabled.

---

## Installing and uninstalling

```powershell
# What is available?
tcpkg list                                # everything from all sources
tcpkg list -n "My Local Feed"             # one source only
tcpkg list -t workload                    # workloads only

# Install / upgrade / remove
tcpkg install MyCustomLibraryPackage
tcpkg install MyCustomLibraryPackage --version 1.2.3
tcpkg upgrade MyCustomLibraryPackage
tcpkg uninstall MyCustomLibraryPackage
tcpkg uninstall MyCustomLibraries.Workload --include-dependencies

# What is installed?
tcpkg list --installed
```

Run all of these from an **elevated** shell.

---

## Versioning

All samples use [semantic versioning](https://semver.org/) — `major.minor.patch`, optionally with a
prerelease suffix such as `1.3.0-beta1`.

Two rules that matter in practice:

1. **Always increment the version when the content changes.** Feeds cache aggressively; a client
   that already has `1.2.3` will not re-download a modified `1.2.3`.
2. **Keep version-dependent scripts in sync.** The PLC library sample encodes the library version
   in `chocolateyuninstall.ps1`, because `RepTool.exe` identifies a library by
   `Name, Version (Vendor)`. Bumping the `.nuspec` alone would leave a package that installs
   cleanly but cannot uninstall.

`GitVersion.yml` in the repository root derives versions automatically from git history and tags
(`v1.2.3`), which is what the CI workflow uses.

---

## Continuous integration

`.github/workflows/build.yml` builds every sample on each push and pull request:

1. Checkout with full history (required by GitVersion).
2. Determine the version with **GitVersion**.
3. Pack all samples via `build/pack.ps1 -Version <computed>`.
4. Verify every produced `.nupkg`: it is unzipped and checked for
   `tools/chocolateyinstall.ps1`, a well-formed `.nuspec`, and — for workloads — the
   `<packageType name="Workload" />` declaration that the `Workload` tag alone does not provide.
5. Lint all PowerShell with **PSScriptAnalyzer** using `PSScriptAnalyzerSettings.psd1`.
6. Upload the `.nupkg` files as a build artifact.
7. On a `v*` tag, attach them to a GitHub Release.

Run the same lint locally before pushing:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

Because `build/pack.ps1` falls back to `nuget pack`, the workflow runs on a stock
`windows-latest` runner with no TwinCAT installed. If you want the pipeline to use the real
`tcpkg pack`, install the Package Manager in an extra step first — see
[`docs/build-and-publish.md`](docs/build-and-publish.md).

---

## Repository layout

```
.
├── README.md                      # This file – general TcPkg concepts
├── LICENSE
├── GitVersion.yml                 # Semantic versioning configuration
├── PSScriptAnalyzerSettings.psd1  # Lint rules shared by CI and local runs
├── build/
│   ├── pack.ps1                   # Packs one or all samples
│   └── set-version.ps1            # Rewrites <version> in a sample's nuspec
├── docs/
│   ├── nuspec-reference.md        # Field-by-field nuspec reference
│   ├── lifecycle-scripts.md       # Chocolatey hooks in a TwinCAT context
│   ├── build-and-publish.md       # Packing, feeds, signing, CI/CD
│   ├── workloads.md               # Meta-packages
│   └── images/
├── samples/
│   ├── plc-library-package/
│   ├── boot-project-package/
│   ├── xae-project-template-package/
│   ├── xae-shell-settings-package/
│   └── plc-library-workload/
└── .github/workflows/build.yml
```

Every sample follows the same `src/` structure described in
[Anatomy of a TcPkg package](#anatomy-of-a-tcpkg-package).

---

## Documentation

| Document | Content |
| --- | --- |
| [`docs/nuspec-reference.md`](docs/nuspec-reference.md) | Every `.nuspec` element, the TcPkg tag vocabulary, and the `<files>` mapping rules. |
| [`docs/lifecycle-scripts.md`](docs/lifecycle-scripts.md) | What each Chocolatey hook does, execution order, TwinCAT registry paths, error handling, and reusable snippets. |
| [`docs/build-and-publish.md`](docs/build-and-publish.md) | `tcpkg pack`, feed types, signature verification, versioning strategy, and CI/CD pipelines for GitHub Actions and Azure DevOps. |
| [`docs/workloads.md`](docs/workloads.md) | Building meta-packages that install several packages at once. |

---

## Disclaimer

This is a personal collection of samples, not a peer-reviewed publication or an official Beckhoff
product. No representation is made as to the accuracy, completeness, correctness, suitability, or
validity of any information here, and no liability is accepted for any errors, omissions, or for
any loss or damage arising from its use. Everything is provided **as is**.

The views expressed are those of the authors and do not necessarily reflect the position of any
employer, organisation, or company.

Several samples modify machine-wide state — the TwinCAT boot folder, the PLC library repository,
the IDE installation directory. **Always test on a development machine before deploying to
production hardware.**

---

## License

Released under the [MIT License](LICENSE).

TwinCAT, TcXaeShell, and Beckhoff are trademarks of Beckhoff Automation GmbH & Co. KG. This
repository is not affiliated with or endorsed by Beckhoff Automation.

### Acknowledgements

The documentation and the workload sample were inspired by
[Beckhoff-USA-Community/AAG_Custom-TcPkg-And-Workload](https://github.com/Beckhoff-USA-Community/AAG_Custom-TcPkg-And-Workload).
