# PLC library workload

A **workload** — a meta-package that installs a whole set of packages with one command. It ships no
files of its own; everything happens through `<dependencies>`.

| | |
| --- | --- |
| **Package ID** | `MyCustomLibraries.Workload` |
| **Variant** | `VariantXAE` — engineering systems |
| **Payload** | none |
| **Mechanism** | TcPkg dependency resolution |

---

## What the package does

`tcpkg install MyCustomLibraries.Workload` makes TcPkg resolve the dependency graph, download every
component package, and run each component's own `chocolateyinstall.ps1`. The workload's own hooks
are empty.

This sample depends on the [PLC library package](../plc-library-package) and is meant to be
extended with your own library packages.

## When to use it

- **Onboarding.** A new engineering station needs eight internal packages — one command instead of
  eight.
- **Machine types.** `MachineTypeABC.Workload` pulls in the boot project, the HMI, and the
  documentation package in matching versions.
- **Library sets.** All motion-related libraries your team maintains, installed together.
- **Reproducible environments.** With pinned dependency versions the workload acts as a lockfile
  for a machine configuration.

---

## Contents

```
plc-library-workload/
└── src/                                       # Everything here goes into the .nupkg
    ├── MyCustomLibraries.Workload.nuspec       # Workload manifest
    ├── PackageIcon.png                         # Icon shown in the Package Manager UI
    └── tools/
        ├── chocolateyinstall.ps1               # Empty by design
        ├── chocolateyuninstall.ps1             # Empty by design
        └── chocolateybeforemodify.ps1          # Empty by design
```

The `tools` scripts must exist because the package layout expects them, but they contain only
explanatory comments. All work is done by dependency resolution.

---

## How it works

Two elements make this a workload rather than a normal package:

```xml
<!-- 1. Declares the package type. Without this, TcPkg treats it as a regular
        package no matter what the tags say, and `tcpkg list -t workload`
        will not show it. -->
<packageTypes>
  <packageType name="Workload" />
</packageTypes>

<!-- 2. The component packages. A workload without dependencies installs nothing. -->
<dependencies>
  <dependency id="MyCustomLibraryPackage" version="[1.2.3]" />
</dependencies>
```

The `Workload` tag is additionally present in `<tags>` for search and filtering, but it is
`<packageTypes>` that determines the actual behaviour.

### Pin exact versions

```xml
<dependency id="MyCustomLibraryPackage" version="[1.2.3]" />   <!-- exactly 1.2.3 -->
<dependency id="MyCustomLibraryPackage" version="1.2.3" />     <!-- 1.2.3 or newer -->
```

Use the bracketed form. A workload exists to produce a **known** machine state; an open range means
two machines installed a week apart can end up with different library versions.

### Install and uninstall behaviour

| Command | Effect |
| --- | --- |
| `tcpkg install MyCustomLibraries.Workload` | Installs the workload **and** every component package |
| `tcpkg uninstall MyCustomLibraries.Workload` | Removes only the workload entry; components stay installed |
| `tcpkg uninstall MyCustomLibraries.Workload --include-dependencies` | Removes the workload and its components |

Components that another installed package also depends on are kept.

If any component fails to install, the whole operation fails.

---

## Building

Component packages must be in the feed **before** the workload is installed — TcPkg resolves
dependencies at install time.

```powershell
# 1. Pack and publish every component package first
.\build\pack.ps1 -Sample plc-library-package -OutputDirectory C:\LocalFeed

# 2. Pack and publish the workload
.\build\pack.ps1 -Sample plc-library-workload -OutputDirectory C:\LocalFeed
```

Or directly:

```powershell
tcpkg pack "samples\plc-library-workload\src\MyCustomLibraries.Workload.nuspec" -o "C:\LocalFeed"
```

## Installing

```powershell
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"   # once per machine
tcpkg config unset -n VerifySignatures                   # once, dev machines only

# Confirm TcPkg recognises it as a workload
tcpkg list -n "My Local Feed" -t workload

tcpkg install MyCustomLibraries.Workload
```

## Uninstalling

```powershell
tcpkg uninstall MyCustomLibraries.Workload --include-dependencies
```

---

## Adapting it to your own workload

1. **Create and publish the component packages first.** Use the other samples as a starting point.
   Note each package's exact `<id>` and `<version>`.

2. **Update the manifest** — `<id>` (the `.Workload` suffix is a useful convention), `<version>`,
   `<title>`, `<authors>`, `<description>`, and the `Category` tag. Keep `<packageTypes>` and the
   `Workload` tag.

3. **List the components** with exact versions:
   ```xml
   <dependencies>
     <dependency id="Company.MotionLibrary"  version="[2.1.0]" />
     <dependency id="Company.CommsLibrary"   version="[1.4.2]" />
     <dependency id="Company.ProjectTemplate" version="[1.0.0]" />
   </dependencies>
   ```

4. **Leave the `tools` scripts empty.**

5. **Pack, publish, and test in a clean environment** — installing the workload should bring in
   every component, and `--include-dependencies` should remove them again.

### Keeping dependencies in sync

Every time a component version changes, the `<dependency>` entry must be updated and the workload
republished. Otherwise it keeps installing the old, pinned versions — correct behaviour, but rarely
what was intended.

Generating the block from the feed avoids drift:

```powershell
$feed = "C:\LocalFeed"
Get-ChildItem $feed -Filter *.nupkg |
    Where-Object { $_.Name -notlike '*Workload*' } |
    ForEach-Object {
        if ($_.BaseName -match '^(?<id>.+?)\.(?<ver>\d+\.\d+\.\d+.*)$') {
            '  <dependency id="{0}" version="[{1}]" />' -f $Matches.id, $Matches.ver
        }
    }
```

### Versioning

| Change | Workload bump |
| --- | --- |
| A component gets a patch update | patch |
| A component is added | minor |
| A component is removed, or a component makes a breaking change | major |

### Nesting

Workloads may depend on other workloads, which scales well when several teams each maintain their
own:

```xml
<dependencies>
  <dependency id="Company.Libraries.Workload" version="[1.0.0]" />
  <dependency id="Company.Templates.Workload" version="[1.0.0]" />
</dependencies>
```

Keep the graph acyclic and shallow.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Not listed by `tcpkg list -t workload` | `<packageTypes>` element missing | Add `<packageTypes><packageType name="Workload" /></packageTypes>` |
| `Unable to resolve dependency` | A component package is not in any registered feed | Pack and publish the components first, then `tcpkg list -n "<feed>"` to confirm |
| Wrong component version installed | Open-ended version range | Use the exact form `version="[1.2.3]"` |
| Uninstall leaves components behind | Expected default behaviour | Add `--include-dependencies` |
| Workload installs but nothing else happens | `<dependencies>` is empty | Add the component packages |

---

## See also

- [`docs/workloads.md`](../../docs/workloads.md) — the full workload guide
- [`docs/nuspec-reference.md`](../../docs/nuspec-reference.md) — `<packageTypes>` and version ranges
- [PLC library package](../plc-library-package) — the component this workload installs
