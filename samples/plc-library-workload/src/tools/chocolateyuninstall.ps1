# ------------------------------------------------------------------------------
# Workload uninstall hook - intentionally empty.
#
# `tcpkg uninstall MyCustomLibraries.Workload` removes only the workload entry.
# Pass --include-dependencies to remove the component packages as well; each of
# them then runs its own chocolateyuninstall.ps1.
#
# See ../../../../docs/workloads.md
# ------------------------------------------------------------------------------
