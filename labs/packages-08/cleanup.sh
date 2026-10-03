#!/bin/bash
# packages-08 cleanup: pkg_restore puts /etc/dnf/modules.d back as it
# was at the first start (so the nodejs module is no longer enabled)
# and removes every package the lab or the solution installed, the
# Node.js packages and the imported repo key included. When that
# fails, the snapshot stays for the next reset and the exit status
# is 1.
source /opt/linux-labs/lib/packages.sh

LAB=packages-08
STATE_FILE=/opt/linux-labs/state/$LAB

rc=0
pkg_restore "$LAB" || rc=1
if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
