#!/bin/bash
# Reference solution for packages-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package mc
# solve: package gpm-libs
# solve: path /etc/chrony.conf.rpmnew
# solve: path /root/chrony.conf.old
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]: chronyd failed at an invalid directive
if systemctl is-active --quiet chronyd; then exit 1; fi
systemctl status chronyd >/dev/null || true
journalctl -u chronyd -n 20 --no-pager | grep 'Invalid directive' >/dev/null

# Step 2 [sudo]
# rpm -V exits 1 when a file differs
{ rpm -V chrony || true; } | grep ' /etc/chrony.conf$' | grep 5 >/dev/null
ls -l /etc/chrony.conf*
diff /etc/chrony.conf /etc/chrony.conf.rpmnew >/dev/null || true

# Step 3 [sudo]
cp -p /etc/chrony.conf /root/chrony.conf.old
cp /etc/chrony.conf.rpmnew /etc/chrony.conf
printf '%s\n' '' '# Local settings' 'allow 172.25.250.0/24' \
	'local stratum 10' | tee -a /etc/chrony.conf >/dev/null
rm /etc/chrony.conf.rpmnew
restorecon -v /etc/chrony.conf

# Step 4 [sudo]
chronyd -p >/dev/null
systemctl enable chronyd
systemctl restart chronyd
systemctl is-active chronyd
chronyc sources

# Step 5 [sudo]
dnf history list </dev/null
dnf history info last </dev/null | grep -E '^ +Install +mc-' >/dev/null
rpm -qf /usr/bin/mc

# Step 6 [sudo]
dnf -y history undo last </dev/null
if rpm -q mc gpm-libs >/dev/null 2>&1; then exit 1; fi
