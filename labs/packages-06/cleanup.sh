#!/bin/bash
# packages-06 cleanup. pkg_restore removes zsh, ksh and the Rocky
# release key that the installs imported, and puts /etc/yum.repos.d back
# as it was at the first start: labrepo.repo (and any other repository
# file the lab added) goes, the repositories setup.sh disabled are
# enabled again. labrepo.repo is removed first so that no package step
# of the restore can use it. Prints nothing.
source /opt/linux-labs/lib/packages.sh

rc=0
rm -f /etc/yum.repos.d/labrepo.repo
pkg_restore packages-06 || rc=1
# Metadata cache of the lab repositories
rm -rf /var/cache/dnf/lab-baseos* /var/cache/dnf/lab-appstream*
rm -f /opt/linux-labs/state/packages-06
exit "$rc"
