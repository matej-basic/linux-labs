#!/bin/bash
# Reference solution for systemd-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM. The reboot
# of step 5 is done by test-lab.sh (# solve: reboot).
#
# solve: path /var/crash/lab
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q kexec-tools >/dev/null || dnf -y install kexec-tools >/dev/null
# Step 2 [sudo]
grubby --update-kernel=ALL --args=crashkernel=256M
# Step 3 [sudo]
mkdir -p /var/crash/lab
sed -i 's|^path .*|path /var/crash/lab|' /etc/kdump.conf
sed -i \
	's|^core_collector .*|core_collector makedumpfile -l --message-level 7 -d 17|' \
	/etc/kdump.conf
grep -qx 'path /var/crash/lab' /etc/kdump.conf
grep -qx 'core_collector makedumpfile -l --message-level 7 -d 17' /etc/kdump.conf
# Step 4 [sudo]
systemctl enable kdump
