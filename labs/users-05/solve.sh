#!/bin/bash
# Reference solution for users-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/sudoers.d/50-lab
# solve: path /home/webops
# solve: path /home/auditor
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 2 [user]
run_as_student <<'STEPS'
cat > ~/50-lab <<'SUDOERS'
Cmnd_Alias HTTPD_CMDS = /usr/bin/systemctl restart httpd, \
                        /usr/bin/systemctl status httpd
%helpdesk ALL=(root) NOPASSWD: HTTPD_CMDS
auditor   ALL=(root) /usr/bin/journalctl
SUDOERS
visudo -c -f ~/50-lab >/dev/null
STEPS

# Step 3 [sudo]
home=$(getent passwd "$SOLVE_USER" | cut -d: -f6)
install -m 0440 -o root -g root "$home/50-lab" /etc/sudoers.d/50-lab
visudo -c >/dev/null
rm -f "$home/50-lab"

# Step 4 [sudo]
sudo -l -U webops >/dev/null
sudo -l -U auditor >/dev/null
sudo -l -U webops /usr/bin/systemctl stop httpd >/dev/null && exit 1
sudo -l -U auditor /usr/bin/journalctl -u sshd >/dev/null

# The task user keeps passwordless sudo
run_as_student 'sudo -n true'
