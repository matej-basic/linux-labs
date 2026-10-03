#!/bin/bash
# Reference solution for systemd-11, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM. The reboot
# of step 6 is done by test-lab.sh (# solve: reboot).
#
# solve: path /etc/sysctl.d/80-labtune.conf
# solve: path /etc/sysctl.d/99-zz-legacy.conf
# solve: path /etc/tmpfiles.d/labapp.conf
# solve: path /run/labapp
# solve: path /var/tmp/labcache
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat > /etc/sysctl.d/80-labtune.conf <<'EOT'
fs.inotify.max_user_watches = 524288
net.core.somaxconn = 4096
kernel.panic = 10
EOT
# Step 2 [sudo]
sed -i '/^[[:space:]]*net\.core\.somaxconn/d' /etc/sysctl.d/99-zz-legacy.conf
grep -q '^vm.vfs_cache_pressure = 150$' /etc/sysctl.d/99-zz-legacy.conf
# Step 3 [sudo]
sysctl --system >/dev/null
[ "$(sysctl -n net.core.somaxconn)" = 4096 ]
# Step 4 [sudo]
printf '%s\n' "d /run/labapp 0750 $SOLVE_USER root -" \
	'd /var/tmp/labcache 1777 root root 7d' > /etc/tmpfiles.d/labapp.conf
# Step 5 [sudo]
systemd-tmpfiles --create /etc/tmpfiles.d/labapp.conf
