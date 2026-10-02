#!/bin/bash
# packages-01 cleanup: pkg_restore puts the package set back as it was
# at the first start. Setup removed git and the solution installs it, so
# git (and what it pulled in) goes, or comes back if it was installed
# before the lab. The state file goes too.
source /opt/linux-labs/lib/packages.sh

rc=0
pkg_restore packages-01 || rc=1
rm -f /opt/linux-labs/state/packages-01
exit "$rc"
