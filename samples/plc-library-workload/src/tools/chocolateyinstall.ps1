# ------------------------------------------------------------------------------
# Workload install hook - intentionally empty.
#
# A workload ships no payload of its own. TcPkg resolves the <dependencies>
# declared in the .nuspec and runs the install script of every component
# package instead. This file only has to exist so that the package follows
# the expected layout.
#
# See ../../../../docs/workloads.md
# ------------------------------------------------------------------------------
