#!/bin/bash
# Reference solution for dns-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/NetworkManager/conf.d/90-lab.conf
# solve: path /opt/linux-labs/state/dns-05.orig
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student <<'STEPS'
cat /etc/resolv.conf
grep -v '^#' /etc/nsswitch.conf | grep '^hosts:'
timeout 25 getent ahosts rockylinux.org || true
getent ahosts www.rockylinux.org || true
nmcli -g IP4.DNS device show
STEPS

# Step 2 [sudo]
NetworkManager --print-config | sed -n '/^\[main\]/,/^\[/p'
grep -rn 'dns\|rc-manager' /etc/NetworkManager/NetworkManager.conf \
	/etc/NetworkManager/conf.d/ || true
journalctl -u NetworkManager --no-pager | grep 'dns-mgr' | tail -n 3 || true

# Step 3 [sudo]
rm -f /etc/NetworkManager/conf.d/90-lab.conf

# Step 4 [sudo]
lsattr /etc/resolv.conf
chattr -i /etc/resolv.conf

# Step 5 [sudo]
nmcli general reload
sleep 2
cat /etc/resolv.conf

# Step 6 [sudo]
grep -n 'www.rockylinux.org' /etc/hosts
sed -i '/[[:space:]]www\.rockylinux\.org/d' /etc/hosts

# Step 7 [user]
run_as_student <<'STEPS'
getent ahosts rockylinux.org
getent ahosts www.rockylinux.org
STEPS
