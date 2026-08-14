# XAE Shell settings package

Imports a Visual Studio settings file (`.vssettings`) into TwinCAT XAE Shell, so every engineering
station uses the same IDE layout, editor behaviour, fonts, and shortcuts.

| | |
| --- | --- |
| **Package ID** | `TcXaeShellSettings` |
| **Variant** | `VariantXAE` — engineering systems |
| **Target** | TcXaeShell user settings |
| **Mechanism** | `TcXaeShell.exe /command "Tools.ImportandExportSettings /import:…"` |
| **Origin** | Consolidated from [`tcpkg-tcxaeshell-settings-package`](https://github.com/philippleidig/tcpkg-tcxaeshell-settings-package) |

---

## What the package does

On install it launches TcXaeShell with Visual Studio's settings import command and waits for it to
finish. The shipped `General.vssettings` is applied to the current user's IDE profile.

Before an upgrade or uninstall, `chocolateybeforemodify.ps1` exports the *current* settings to a
timestamped backup under `%LOCALAPPDATA%\TcXaeShellSettingsBackup\`, so a rollout can be undone.

Uninstall does **not** revert the settings — Visual Studio has no "unimport" operation. The
uninstall script prints instructions for resetting the IDE manually instead.

## When to use it

- **Team consistency.** Identical toolbar layouts, window docking, and editor settings make
  screen-sharing and pair debugging far less painful.
- **Coding standards enforced by the IDE.** Tabs vs. spaces, indentation, line endings, and
  formatting rules travel with the package.
- **Onboarding.** A new engineer's IDE is configured in one command.
- **Accessibility baselines.** Font sizes and colour themes rolled out centrally.
- **Kiosk / lab machines.** Reset a shared workstation to a known IDE state.

---

## Contents

```
xae-shell-settings-package/
└── src/                                       # Everything here goes into the .nupkg
    ├── TcXaeShellSettings.nuspec               # Package manifest
    ├── General.vssettings                      # The settings payload
    ├── PackageIcon.png                         # Icon shown in the Package Manager UI
    └── tools/
        ├── chocolateyinstall.ps1               # Imports the settings
        ├── chocolateyuninstall.ps1             # Prints reset instructions
        ├── chocolateybeforemodify.ps1          # Backs up current settings
        ├── LICENSE.txt
        └── VERIFICATION.txt
```

Note the manifest maps the payload explicitly rather than placing it inside `tools/`:

```xml
<file src="General.vssettings" target="tools\General.vssettings" />
```

Both approaches work; this one keeps the settings file visible next to the manifest.

---

## How it works

### `chocolateyinstall.ps1`

1. Resolves `General.vssettings` next to the script and verifies it exists.
2. Verifies the IDE is installed:
   ```powershell
   $tcxaeshellPath = "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe"
   ```
3. Runs the import and waits:
   ```powershell
   $importArgs = "/command `"Tools.ImportandExportSettings /import:$settingsFile`""
   $process = Start-Process -FilePath $tcxaeshellPath -ArgumentList $importArgs -Wait -PassThru
   ```
4. Reports the exit code — a non-zero code means the settings may have been applied only partially.

### `chocolateybeforemodify.ps1`

Exports the current settings before they are replaced:

```
%LOCALAPPDATA%\TcXaeShellSettingsBackup\backup_yyyyMMdd_HHmmss.vssettings
```

A failed backup is a warning, not an error — the upgrade continues.

### `chocolateyuninstall.ps1`

Prints how to reset the IDE:

1. **Tools → Import and Export Settings…**
2. Select **Reset all settings**
3. Follow the wizard

Or restore one of the automatic backups:

```powershell
& "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe" `
    /command "Tools.ImportandExportSettings /import:$env:LOCALAPPDATA\TcXaeShellSettingsBackup\backup_20260101_120000.vssettings"
```

---

## Notes and limitations

- **The IDE path is hard-coded.** Unlike the other samples, TcXaeShell registers itself under a
  Visual Studio hive rather than the TwinCAT registry key, so the script uses the default install
  path. Adjust it if your installation differs, or extend the script to probe several candidates.
- **Settings are per user.** The import applies to the account running the install. On a machine
  with several engineering users, each needs the package applied in their own context.
- **Close the IDE first.** Importing while TcXaeShell is open can leave the running instance with
  stale settings, or the import may target the wrong instance.
- **Uninstall is informational only.** By design — see above.

---

## Building

```powershell
# From the repository root
.\build\pack.ps1 -Sample xae-shell-settings-package

# Or directly
tcpkg pack "samples\xae-shell-settings-package\src\TcXaeShellSettings.nuspec" -o "C:\LocalFeed"
```

The manifest carries a concrete `<version>` so it packs without extra arguments. In CI the version
is overridden:

```powershell
.\build\pack.ps1 -Sample xae-shell-settings-package -Version 1.4.0
```

## Installing

```powershell
tcpkg source add -n "My Local Feed" -s "C:\LocalFeed"   # once per machine
tcpkg config unset -n VerifySignatures                   # once, dev machines only
tcpkg install TcXaeShellSettings
```

## Uninstalling

```powershell
tcpkg uninstall TcXaeShellSettings
```

---

## Adapting it to your own settings

1. **Configure TcXaeShell** exactly the way you want it — layout, fonts, colours, editor options,
   shortcuts.

2. **Export the settings:** *Tools → Import and Export Settings… → Export selected environment
   settings*. Choose only the categories you actually want to standardise; exporting everything
   also carries over personal state such as recent-file lists and window positions that may not
   suit other screen setups.

3. **Replace the payload:** overwrite `src/General.vssettings` with your export. If you rename the
   file, update both the manifest and the script:
   ```xml
   <file src="CompanyStandard.vssettings" target="tools\CompanyStandard.vssettings" />
   ```
   ```powershell
   $settingsFileName = "CompanyStandard.vssettings"
   ```

4. **Update the manifest** — `<id>`, `<version>`, `<title>`, `<authors>`, `<description>`, and the
   `Category` tag. Keep `VariantXAE`.

5. **Pack, install, and verify** in a fresh IDE profile.

### Shipping several profiles

Create one package per profile (`TcXaeShellSettings.Standard`, `TcXaeShellSettings.Accessibility`)
rather than one package with a switch. Package managers are good at "install exactly one of these";
they have no concept of runtime options.

---

## Applying settings manually

Useful for testing without packing:

```powershell
# Import
& "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe" `
    /command "Tools.ImportandExportSettings /import:C:\Path\To\settings.vssettings"

# Export
& "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe" `
    /command "Tools.ImportandExportSettings /export:C:\Path\To\backup.vssettings"

# Reset to defaults
& "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe" `
    /command "Tools.ImportandExportSettings /reset"
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `TcXaeShell not found at: …` | Installed to a non-default path, or not installed | Correct `$tcxaeshellPath` in the scripts |
| Install succeeds, IDE unchanged | The IDE was open during the import, or a different user account was used | Close TcXaeShell and reinstall in the target user's context |
| IDE opens and stays open during install | `/command` did not terminate the instance | Ensure no other TcXaeShell instance is running before installing |
| Non-zero exit code warning | Some settings categories could not be applied | Compare the exported categories with the target IDE version |
| Settings partly applied | The `.vssettings` was exported from a different Visual Studio / TcXaeShell version | Re-export from the same version you deploy to |

---

## See also

- [`docs/lifecycle-scripts.md`](../../docs/lifecycle-scripts.md) — IDE automation via `/command`
- [`docs/nuspec-reference.md`](../../docs/nuspec-reference.md) — explicit payload mapping in `<files>`
- [XAE project template package](../xae-project-template-package) — standardising projects instead of the IDE
