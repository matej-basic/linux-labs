#!/bin/bash
# packages-03 cleanup: remove the file list. pkg_restore puts the package
# set back as at the first start (curl stays, it is part of the base
# system, and goes only if setup had to install it).
source /opt/linux-labs/lib/packages.sh

rm -f /tmp/curl-files.txt
rc=0
pkg_restore packages-03 || rc=1
exit "$rc"
