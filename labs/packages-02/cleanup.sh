#!/bin/bash
# packages-02 cleanup: pkg_restore removes htop, EPEL and its signing
# key, and puts back what was installed before the lab (including the
# repository files). The state file goes too.
source /opt/linux-labs/lib/packages.sh

rc=0
pkg_restore packages-02 || rc=1
rm -f /opt/linux-labs/state/packages-02
exit "$rc"
