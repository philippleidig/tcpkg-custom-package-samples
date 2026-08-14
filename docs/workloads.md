# Workloads

A **workload** is a meta-package: it carries no payload of its own and exists only to install a set
of other packages through dependencies.

| | Package | Workload |
| --- | --- | --- |
| Contains files | ✅ | ❌ |
| Contains install logic | ✅ | ❌ (empty hooks) |
| Contains dependencies | optional | ✅ — this is the whole point |
| `<packageTypes>` element | ❌ | ✅ `Workload` |
| Listed by `tcpkg list -t workload` | ❌ | ✅ |

Beckhoff itself uses workloads to express installation profiles such as *TwinCAT Standard* or
*TwinCAT XAE*. The same mechanism is available for your own packages.

---

## When to use one

- **Onboarding.** A new engineering station needs eight internal packages. One
  `tcpkg install Company.Engineering.Workload` instead of eight commands.
- **Machine types.** `MachineTypeABC.Workload` pulls in the boot project, the HMI, and the
  documentation package in matching versions.
- **Library sets.** A "motion" workload that installs every motion-related PLC library your team
  maintains.
- **Reproducible environments.** Pinning exact dependency versions makes a workload a lockfile for
  a machine configuration.

---

## Structure

```
samples/plc-library-workload/
├── README.md
└── src/
    ├── MyCustomLibraries.Workload.nuspec
    ├── PackageIcon.png
    └── tools/
        ├── chocolateyinstall.ps1        # empty
        ├── chocolateyuninstall.ps1      # empty
        └── chocolateybeforemodify.ps1   # empty
```

The `tools` scripts must exist — the package layout expects them — but they stay empty. All work is
done by TcPkg's dependency resolution.

---

## The manifest

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>MyCustomLibraries.Workload</id>
    <version>1.0.0</version>
    <title>My Custom PLC Libraries</title>
    <authors>Your Name</authors>
    <description>Installs the complete set of custom PLC libraries.</description>
    <icon>icon.png</icon>

    <!-- Required: this is what makes it a workload -->
    <packageTypes>
      <packageType name="Workload" />
    </packageTypes>

    <!-- Include the Workload tag as well -->
    <tags>CategoryMy&#160;Custom Workload VariantXAE</tags>

    <!-- The component packages, pinned to exact versions -->
    <dependencies>
      <dependency id="MyCustomLibraryPackage" version="[1.2.3]" />
      <dependency id="AnotherLibraryPackage"  version="[2.0.1]" />
    </dependencies>
  </metadata>

  <files>
    <file src="PackageIcon.png" target="icon.png" />
    <file src="tools\**" target="tools" />
  </files>
</package>
```

### Two things are mandatory

1. **`<packageTypes><packageType name="Workload" /></packageTypes>`** — without it TcPkg treats the
   package as a normal package no matter what the tags say, and `tcpkg list -t workload` will not
   show it.
2. **`<dependencies>`** — a workload without dependencies installs nothing.

### Pin exact versions

```xml
<dependency id="MyCustomLibraryPackage" version="[1.2.3]" />   <!-- exactly 1.2.3 -->
<dependency id="MyCustomLibraryPackage" version="1.2.3" />     <!-- 1.2.3 or newer -->
```

Use the bracketed form. A workload's purpose is to produce a **known** machine state; an open range
means two machines installed a week apart can end up with different library versions.

---

## Workflow

Component packages must exist in the feed **before** the workload is installed — TcPkg resolves
dependencies at install time.

```powershell
# 1. Pack and publish every component package
tcpkg pack "samples\plc-library-package\src\MyCustomLibraryPackage.nuspec" -o "C:\LocalFeed"

# 2. Pack and publish the workload
tcpkg pack "samples\plc-library-workload\src\MyCustomLibraries.Workload.nuspec" -o "C:\LocalFeed"

# 3. Register the feed and allow unsigned packages (once)
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"
tcpkg config unset -n VerifySignatures

# 4. Verify the workload is recognised as such
tcpkg list -n "My Local Feed" -t workload

# 5. Install everything
tcpkg install MyCustomLibraries.Workload

# 6. Remove the workload and everything it brought in
tcpkg uninstall MyCustomLibraries.Workload --include-dependencies
```

### What happens on install

1. TcPkg downloads the workload manifest.
2. It resolves the dependency graph and downloads every component package.
3. Each component runs **its own** `chocolateyinstall.ps1`.
4. The workload's own (empty) hooks run.

If any component fails, the whole operation fails.

### What happens on uninstall

`tcpkg uninstall MyCustomLibraries.Workload` removes only the workload entry — the components stay
installed. Add `--include-dependencies` to remove them as well.

Components that another installed package also depends on are kept.

---

## Versioning a workload

The workload version is independent of its components. A common convention:

| Change | Workload bump |
| --- | --- |
| A component gets a patch update | patch |
| A component is added | minor |
| A component is removed, or a component makes a breaking change | major |

Every time a component version changes, the workload's `<dependency>` entry must be updated and the
workload republished. Otherwise it keeps installing the old, pinned versions — which is correct
behaviour, but usually not what you intended.

Generating the dependency block from the feed avoids drift:

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

---

## Nesting

Workloads may depend on other workloads:

```xml
<dependencies>
  <dependency id="Company.Libraries.Workload" version="[1.0.0]" />
  <dependency id="Company.Templates.Workload" version="[1.0.0]" />
  <dependency id="Company.Documentation"      version="[2.1.0]" />
</dependencies>
```

This scales well for organisations with several teams: each team maintains its own workload, and a
top-level workload composes them. Keep the graph acyclic and shallow — deep chains make it hard to
reason about what a single install command actually does.

---

## See also

- [`nuspec-reference.md`](nuspec-reference.md) — `<packageTypes>` and `<dependencies>` in detail
- [`build-and-publish.md`](build-and-publish.md) — feeds and publishing
- [PLC library workload sample](../samples/plc-library-workload)
