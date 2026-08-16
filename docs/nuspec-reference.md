# `.nuspec` reference

The `.nuspec` file is the manifest of a TcPkg package. It is a standard
[NuGet manifest](https://learn.microsoft.com/en-us/nuget/reference/nuspec); TcPkg adds meaning to
the `<tags>` element and to `<packageTypes>`, and ignores fields that only make sense on
nuget.org.

This page documents every element used by the samples in this repository.

---

## Skeleton

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <!-- identity, description, tags, dependencies -->
  </metadata>
  <files>
    <!-- disk -> package mapping -->
  </files>
</package>
```

### Schema version

The namespace must be one that NuGet knows. NuGet defines exactly six, and the newest — the one
all samples in this repository use — is:

```
http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd
```

The older namespaces (`2010/07`, `2011/08`, `2011/10`, `2012/06`, `2013/01`) are still accepted but
have no advantage.

> **Invented namespaces fail the build.** NuGet has never published a `2015/06` or later
> `nuspec.xsd`, even though the pattern looks like it should continue. Packing a manifest with an
> unknown namespace aborts with
> *"The schema version of '\<id\>' is incompatible with version x.y.z of NuGet"* — a message that
> suggests upgrading NuGet, which does not help, because no NuGet version knows the namespace.

---

## `<metadata>` elements

### Identity

| Element | Required | Description |
| --- | --- | --- |
| `<id>` | ✅ | The package identifier. Must be unique within the feed and is the name used by `tcpkg install <id>`. Allowed characters: letters, digits, `.`, `-`, `_`. Case-insensitive but conventionally PascalCase or dotted (`Company.Product.Component`). |
| `<version>` | ✅ | [Semantic version](https://semver.org/): `major.minor.patch`, optionally `-prerelease` (e.g. `1.2.3-beta1`) and `+build`. |
| `<title>` | ➖ | Human-friendly display name shown in the Package Manager UI. Falls back to `<id>` if omitted. |
| `<authors>` | ✅ | Comma-separated list of authors or the team name. |
| `<owners>` | ➖ | Feed owners; rarely relevant for private feeds. |

> **`$version$` token** — the XAE Shell settings sample uses `<version>$version$</version>` as a
> placeholder that CI replaces with the version computed by GitVersion. `tcpkg pack` and
> `nuget pack` also accept a `-Version` switch that overrides whatever the file contains, which is
> the approach `build/pack.ps1` uses.

### Descriptive metadata

| Element | Required | Description |
| --- | --- | --- |
| `<description>` | ✅ | Shown by `tcpkg list` and in the UI. One line or a short paragraph. |
| `<releaseNotes>` | ➖ | What changed in this version. Markdown is supported by most viewers. |
| `<summary>` | ➖ | Short form of the description. Largely superseded by `<description>`. |
| `<projectUrl>` | ➖ | Link to documentation or the project homepage. |
| `<copyright>` | ➖ | Copyright notice, e.g. `(c) 2026 Your Company`. |
| `<icon>` | ✅ | Path to a PNG **inside the package**, i.e. the `target` name from the `<files>` section — not the path on disk. 128×128 px is a good default. |
| `<iconUrl>` | ➖ | Deprecated predecessor of `<icon>`. Prefer `<icon>` so the icon works offline. |

### Licensing

| Element | Description |
| --- | --- |
| `<licenseUrl>` | URL to the license text. Deprecated by NuGet in favour of `<license>` but still widely used and accepted. |
| `<license type="expression">MIT</license>` | Preferred modern form. Accepts an [SPDX expression](https://spdx.org/licenses/) (`MIT`, `Apache-2.0`, `MIT OR Apache-2.0`). |
| `<license type="file">tools\LICENSE.txt</license>` | Embeds a license file that is part of the package. |
| `<requireLicenseAcceptance>` | `true` prompts the user to accept the license before installing. Set `true` for third-party or commercial content, `false` for internal packages. |

### `<tags>` — the TcPkg extension point

Tags are a **space-separated** list. TcPkg interprets specific prefixes to decide where and
whether a package shows up.

| Tag | Effect |
| --- | --- |
| `Category<Name>` | Places the package in the *Name* group of the Package Manager UI. The `Category` prefix is stripped for display. |
| `VariantXAE` | Engineering only. Hidden on runtime-only (XAR) systems. |
| `VariantXAR` | Runtime only. Hidden on engineering (XAE) systems. |
| `AllowMultipleVersions` | Permits side-by-side installation of several versions. Required for PLC libraries, where different projects may reference different versions. |
| `Workload` | Marks the package as a workload meta-package. Combine with `<packageTypes>`. |

Anything that does not match a known prefix is treated as a plain search keyword
(`Beckhoff`, `TwinCAT`, `Motion`, …).

#### Multi-word categories

A space would split the tag, so use the XML entity for a non-breaking space, `&#160;`:

```xml
<tags>CategoryMy&#160;Custom&#160;Libraries VariantXAE AllowMultipleVersions</tags>
```

This is displayed as **My Custom Libraries**.

> **Watch the trailing entity.** `CategoryMy&#160;Custom&#160;` ends with a non-breaking space and
> renders as "My Custom " with a trailing blank. Harmless, but easy to avoid.

### `<packageTypes>`

Only needed for workloads:

```xml
<packageTypes>
  <packageType name="Workload" />
</packageTypes>
```

Without this element the package is a normal package regardless of the `Workload` tag, and it will
not be listed by `tcpkg list -t workload`.

### `<dependencies>`

Other packages that TcPkg installs first:

```xml
<dependencies>
  <!-- Exact version -->
  <dependency id="MyCustomLibraryPackage" version="1.2.3" />

  <!-- Minimum version (inclusive) -->
  <dependency id="OtherPackage" version="1.0.0" />

  <!-- Range: >= 1.0.0 and < 2.0.0 -->
  <dependency id="AnotherPackage" version="[1.0.0,2.0.0)" />
</dependencies>
```

Version range syntax follows the
[NuGet rules](https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges):

| Notation | Meaning |
| --- | --- |
| `1.0.0` | ≥ 1.0.0 |
| `[1.0.0]` | exactly 1.0.0 |
| `[1.0.0,2.0.0)` | ≥ 1.0.0 and < 2.0.0 |
| `(1.0.0,)` | > 1.0.0 |
| `[,2.0.0]` | ≤ 2.0.0 |

For workloads, prefer **exact** versions so a workload always produces a reproducible set of
installed packages.

An empty `<dependencies />` element is valid and explicit.

---

## `<files>` — mapping disk to package

```xml
<files>
  <file src="PackageIcon.png" target="icon.png" />
  <file src="tools\**" target="tools" />
  <file src="MyCustomLibraryPlcProject.library" target="tools\MyCustomLibraryPlcProject.library" />
  <file src="docs\**" target="docs" exclude="**\*.tmp" />
</files>
```

| Attribute | Meaning |
| --- | --- |
| `src` | Path **on disk**, relative to the folder containing the `.nuspec`. Supports `*` (one segment) and `**` (recursive). |
| `target` | Path **inside the package**. |
| `exclude` | Semicolon-separated glob patterns to skip. |

### Rules that trip people up

1. **`<icon>` references the target, not the source.** With
   `<file src="PackageIcon.png" target="icon.png" />` the metadata must say `<icon>icon.png</icon>`.
2. **`tools\**` is what makes the hooks run.** The lifecycle scripts are discovered by convention
   at `tools/chocolateyinstall.ps1` inside the package. If the wildcard is missing or the target is
   wrong, the package installs and does nothing.
3. **Paths use backslashes.** `.nuspec` files are Windows-centric; use `tools\**`, not `tools/**`.
4. **Payload can be placed either way.** Files inside `src/tools/` are packed by the wildcard
   automatically. Files next to the `.nuspec` need an explicit `target="tools\..."` mapping. The
   second form keeps large binaries visually separate from the scripts and lets you rename them
   during packing.
5. **Rename during packing.** `target` may differ from the source name, which is handy for scripts
   that expect a fixed file name:
   ```xml
   <file src="ReleaseBuild_v3.library" target="tools\LibraryToInstall.library" />
   ```

### Conventions in this repository

| Path in package | Purpose |
| --- | --- |
| `icon.png` | Icon referenced by `<icon>`. |
| `tools/chocolateyinstall.ps1` | Install hook. |
| `tools/chocolateyuninstall.ps1` | Uninstall hook. |
| `tools/chocolateybeforemodify.ps1` | Pre-upgrade / pre-uninstall hook. |
| `tools/LICENSE.txt` | License of the shipped content. |
| `tools/VERIFICATION.txt` | How to verify the payload. |
| `tools/<payload>` | Everything the install script deploys. |

---

## Complete annotated example

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>MyCustomLibraryPackage</id>
    <version>1.2.3</version>
    <title>My Custom Library Package</title>
    <authors>Your Name</authors>
    <projectUrl>https://www.yourwebsite.com/</projectUrl>
    <copyright>(c) Your Name</copyright>
    <licenseUrl>https://www.yourwebsite.com/license</licenseUrl>
    <requireLicenseAcceptance>true</requireLicenseAcceptance>
    <icon>icon.png</icon>
    <tags>CategoryMy&#160;Custom AllowMultipleVersions VariantXAE</tags>
    <description>This is a custom package for delivering a library.</description>
    <releaseNotes>Initial release.</releaseNotes>
    <dependencies />
  </metadata>

  <files>
    <file src="PackageIcon.png" target="icon.png" />
    <file src="tools\**" target="tools" />
    <file src="MyCustomLibraryPlcProject.library" target="tools\MyCustomLibraryPlcProject.library" />
  </files>
</package>
```

---

## Validating your manifest

`tcpkg pack` reports schema and reference errors, so the fastest check is to pack:

```powershell
tcpkg pack ".\src\MyCustomLibraryPackage.nuspec" -o ".\dist"
```

Then inspect the result — a `.nupkg` is a ZIP archive:

```powershell
Copy-Item .\dist\MyCustomLibraryPackage.1.2.3.nupkg .\inspect.zip
Expand-Archive .\inspect.zip -DestinationPath .\inspect
Get-ChildItem .\inspect -Recurse
```

Confirm that `tools/chocolateyinstall.ps1`, `icon.png`, and your payload are where the scripts
expect them.

---

## See also

- [`lifecycle-scripts.md`](lifecycle-scripts.md) — what the `tools` scripts do
- [`workloads.md`](workloads.md) — meta-packages
- [`build-and-publish.md`](build-and-publish.md) — packing and distribution
