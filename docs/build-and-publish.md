# Building and publishing packages

How to turn a `.nuspec` into a `.nupkg`, get it into a feed, and automate both.

---

## Packing

### With `tcpkg`

```powershell
tcpkg pack "<path-to-nuspec>" -o "<output-directory>"
```

Example:

```powershell
tcpkg pack "samples\plc-library-package\src\MyCustomLibraryPackage.nuspec" -o "C:\LocalFeed"
```

The output file name is `<id>.<version>.nupkg`, e.g. `MyCustomLibraryPackage.1.2.3.nupkg`.

### With `nuget`

Because a TcPkg package *is* a NuGet package, `nuget pack` produces an equivalent artifact. This
matters on build agents where TwinCAT is not installed:

```powershell
nuget pack "samples\plc-library-package\src\MyCustomLibraryPackage.nuspec" `
    -OutputDirectory "dist" `
    -Version "1.2.3" `
    -NoDefaultExcludes
```

> **`-NoDefaultExcludes` is important.** NuGet silently drops files it considers "hidden",
> including anything starting with a dot. If your payload contains such files, add this switch.

### With the helper script

`build/pack.ps1` in this repository wraps both tools:

```powershell
# Every sample -> .\dist
.\build\pack.ps1

# A single sample
.\build\pack.ps1 -Sample plc-library-package

# Custom output folder
.\build\pack.ps1 -Sample boot-project-package -OutputDirectory C:\LocalFeed

# Override the version of every packed sample (CI)
.\build\pack.ps1 -Version 1.4.0

# Force nuget even if tcpkg is available
.\build\pack.ps1 -Packer nuget
```

It discovers `samples/*/src/*.nuspec` automatically, so new samples need no script changes. When
`tcpkg` is not on the `PATH` it falls back to `nuget`, and if neither is present it fails with a
clear message.

### Inspecting the result

A `.nupkg` is a ZIP archive. Verifying the layout catches the most common packaging mistake — a
payload or hook that did not make it into the package:

```powershell
Copy-Item .\dist\MyCustomLibraryPackage.1.2.3.nupkg .\inspect.zip
Expand-Archive .\inspect.zip -DestinationPath .\inspect -Force
Get-ChildItem .\inspect -Recurse | Select-Object FullName
```

Expected content:

```
inspect\
├── MyCustomLibraryPackage.nuspec
├── icon.png
├── [Content_Types].xml
├── _rels\
├── package\
└── tools\
    ├── chocolateyinstall.ps1
    ├── chocolateyuninstall.ps1
    ├── chocolateybeforemodify.ps1
    ├── LICENSE.txt
    ├── VERIFICATION.txt
    └── MyCustomLibraryPlcProject.library
```

---

## Feeds (sources)

A *source* is where `tcpkg` looks for packages.

```powershell
tcpkg source list                                        # show configured sources
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"    # folder
tcpkg source add -n "Company Feed"  -s "\\srv\tc\feed"   # UNC share
tcpkg source add -n "Azure"         -s "https://pkgs.dev.azure.com/org/_packaging/feed/nuget/v3/index.json"
tcpkg source remove -n "My Local Feed"
```

### Feed options

| Type | Setup effort | Good for |
| --- | --- | --- |
| **Local folder** | none | Development, testing a package before release. |
| **UNC share** | none beyond file permissions | Small teams, machines on one domain. Publishing is a file copy. |
| **Azure Artifacts** | moderate | Teams already on Azure DevOps. Versioning, retention, auth included. |
| **GitHub Packages** | moderate | Teams on GitHub. Auth via PAT or `GITHUB_TOKEN`. |
| **Artifactory / ProGet / Nexus** | high | Enterprise, on-premises, fine-grained access control. |

### Publishing

To a folder or share, publishing is just a copy — which is what `-o` already does:

```powershell
tcpkg pack ".\src\MyCustomLibraryPackage.nuspec" -o "\\srv\tc\feed"
```

To a NuGet server:

```powershell
dotnet nuget push ".\dist\MyCustomLibraryPackage.1.2.3.nupkg" `
    --source "https://pkgs.dev.azure.com/org/_packaging/feed/nuget/v3/index.json" `
    --api-key "az"
```

### Signature verification

TcPkg verifies package signatures by default. Custom packages are unsigned, so they are rejected
until verification is disabled:

```powershell
tcpkg config unset -n VerifySignatures     # disable
tcpkg config set -n VerifySignatures -v true   # re-enable
```

> **⚠️ Global setting.** This turns off verification for **every** source, including Beckhoff's
> official feed. Acceptable on development, test, and build machines. For production rollouts,
> sign your packages with a code-signing certificate and leave verification enabled:
>
> ```powershell
> nuget sign ".\dist\MyPackage.1.2.3.nupkg" `
>     -CertificatePath ".\codesign.pfx" `
>     -Timestamper "http://timestamp.digicert.com"
> ```

---

## Versioning

All samples use [semantic versioning](https://semver.org/): `major.minor.patch`, optionally with a
prerelease suffix (`1.3.0-beta1`).

| Change | Bump |
| --- | --- |
| Breaking change — renamed function blocks, incompatible template, different install location | **major** |
| New functionality, backwards compatible | **minor** |
| Bug fix, updated payload, no API change | **patch** |

### Two rules

1. **Always increment when content changes.** Feeds and clients cache by `id` + `version`. A client
   that already installed `1.2.3` will not pick up a re-packed `1.2.3`.
2. **Keep version-dependent scripts in sync.** The PLC library sample encodes the library version
   in `chocolateyuninstall.ps1` because `RepTool.exe` identifies a library by
   `Name, Version (Vendor)`. Bump the `.nuspec` without bumping the script and the package installs
   but cannot be uninstalled.

### Setting the version

Manually, in the `.nuspec`:

```xml
<version>1.2.3</version>
```

With the helper script, which also validates the format:

```powershell
.\build\set-version.ps1 -Sample plc-library-package -Version 1.3.0
.\build\set-version.ps1 -Sample plc-library-package -BumpPatch     # 1.3.0 -> 1.3.1
```

At pack time only, leaving the file untouched:

```powershell
.\build\pack.ps1 -Version 1.3.0
```

### Automatic versioning with GitVersion

[GitVersion](https://gitversion.net/) derives a version from git history and tags, so the version
never has to be committed. `GitVersion.yml` in the repository root configures the branch policy:

| Branch | Mode | Result |
| --- | --- | --- |
| `main` | ContinuousDelivery, patch increment | `1.2.3` |
| `develop` | ContinuousDeployment, minor increment | `1.3.0-alpha.5` |
| `feature/*` | ContinuousDeployment, inherit | `1.3.0-feature-my-change.2` |
| `release/*` | ContinuousDelivery, no increment | `1.3.0-rc.1` |
| `hotfix/*` | ContinuousDelivery, patch increment | `1.2.4-beta.1` |

Tags use the prefix `v`, e.g. `v1.2.3`.

Locally:

```powershell
dotnet tool install --global GitVersion.Tool
dotnet-gitversion /output json
```

### `$version$` token

A `.nuspec` can carry a placeholder that CI replaces:

```xml
<version>$version$</version>
```

```powershell
(Get-Content $nuspecPath) -replace '\$version\$', $version | Set-Content $nuspecPath
```

Passing `-Version` to `pack.ps1` (or to `nuget pack` / `tcpkg pack`) achieves the same without
mutating the file, which is generally cleaner.

---

## CI/CD

### GitHub Actions

`.github/workflows/build.yml` in this repository:

1. Checks out with `fetch-depth: 0` — GitVersion needs the full history.
2. Installs and runs GitVersion.
3. Runs `build/pack.ps1 -Version <computed> -OutputDirectory dist`.
4. Uploads `dist/*.nupkg` as a build artifact.
5. On a `v*` tag, creates a GitHub Release with the packages attached.

Because `pack.ps1` falls back to `nuget pack`, this runs on a stock `windows-latest` runner with no
TwinCAT installed.

To use the real `tcpkg pack` instead, install the Package Manager first:

```yaml
- name: Install TwinCAT Package Manager
  shell: pwsh
  run: |
    $url = "<url-to-TwinCAT-Package-Manager-GUI-Setup.exe>"
    Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\tcpkg-setup.exe"
    Start-Process "$env:TEMP\tcpkg-setup.exe" -NoNewWindow -Wait -ArgumentList @('/install','/quiet')
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    tcpkg --version
```

The installer is not publicly redistributable, so either host it internally or commit it via Git
LFS:

```
# .gitattributes
TwinCAT-Package-Manager-*.exe filter=lfs diff=lfs merge=lfs -text
```

### Azure Pipelines

The equivalent pipeline:

```yaml
trigger:
  branches:
    include: [ main ]
  tags:
    include: [ 'v*' ]

pool:
  vmImage: 'windows-latest'

variables:
  outputDir: '$(Build.ArtifactStagingDirectory)/packages'

steps:
- checkout: self
  fetchDepth: 0

- task: gitversion/setup@1
  displayName: 'Install GitVersion'
  inputs:
    versionSpec: '5.x'

- task: gitversion/execute@1
  displayName: 'Determine Version'
  inputs:
    useConfigFile: true
    configFilePath: 'GitVersion.yml'

- pwsh: |
    New-Item -ItemType Directory -Path "$(outputDir)" -Force | Out-Null
    .\build\pack.ps1 -Version "$(GitVersion.NuGetVersion)" -OutputDirectory "$(outputDir)"
  displayName: 'Pack samples'

- task: PublishPipelineArtifact@1
  displayName: 'Publish packages'
  inputs:
    targetPath: '$(outputDir)'
    artifact: 'packages'

- task: NuGetCommand@2
  displayName: 'Push to Azure Artifacts'
  condition: and(succeeded(), startsWith(variables['Build.SourceBranch'], 'refs/tags/v'))
  inputs:
    command: push
    packagesToPush: '$(outputDir)/*.nupkg'
    publishVstsFeed: '<your-feed-id>'
```

### Recommended pipeline shape

```
push / PR ──► pack all samples ──► upload artifact
                                        │
tag v*  ─────────────────────────────────┴──► push to feed + GitHub Release
```

Pack on every commit so packaging errors surface immediately; publish only from tags so the feed
only ever receives deliberate releases.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `tcpkg` not recognised | Package Manager not installed, or `PATH` not refreshed in the current session | Reinstall, then `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")` |
| Package rejected: signature | `VerifySignatures` is on and the package is unsigned | `tcpkg config unset -n VerifySignatures`, or sign the package |
| Package not listed after packing | Source not registered, or the file is not in the source folder | `tcpkg source list`, then verify the `.nupkg` is present |
| Client keeps installing the old content | Version was not incremented | Bump the version and repack |
| Install succeeds but nothing happens | `tools\**` missing from `<files>`, or hooks named incorrectly | Unzip the `.nupkg` and check `tools/chocolateyinstall.ps1` exists |
| Icon not shown | `<icon>` references the disk name instead of the `target` name | Point `<icon>` at the `target` value |
| Uninstall fails | Version-dependent identifier in the uninstall script is stale | Sync the script with the `.nuspec` version |
| Access denied during install | Shell not elevated | Run as Administrator |

---

## See also

- [`nuspec-reference.md`](nuspec-reference.md) — manifest fields
- [`lifecycle-scripts.md`](lifecycle-scripts.md) — install/uninstall hooks
- [`workloads.md`](workloads.md) — bundling packages
