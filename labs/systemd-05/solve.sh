#!/bin/bash
# Reference solution for systemd-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM. The reboot
# of step 6 is done by test-lab.sh (# solve: reboot).
#
# solve: path /etc/modules-load.d/dummy.conf
# solve: path /etc/modprobe.d/zz-dummy.conf
# solve: path /etc/modprobe.d/pcspkr.conf
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
grubby --update-kernel=ALL --args=consoleblank=0
# Step 2 [sudo]
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
# Step 3 [sudo]
grub2-editenv - unset menu_auto_hide
# Step 4 [sudo]
echo dummy > /etc/modules-load.d/dummy.conf
echo 'options dummy numdummies=2' > /etc/modprobe.d/zz-dummy.conf
# Step 5 [sudo]
echo 'blacklist pcspkr' > /etc/modprobe.d/pcspkr.conf
