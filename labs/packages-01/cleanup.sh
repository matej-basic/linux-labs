#!/bin/bash
# packages-01 cleanup: remove git again (setup removed it, the solution
# installs it) and the state file.
if rpm -q git &>/dev/null; then
	dnf -y remove git &>/dev/null || true
fi
rm -f /opt/linux-labs/state/packages-01
exit 0
