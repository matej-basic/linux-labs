#!/bin/bash
# Reference solution for samba-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# The steps run as the lab user on the workstation and reach the nodes
# with run_on_node. Every run_on_node call that needs no input reads
# /dev/null, because ssh would otherwise consume the step script.
# The packages are installed on the nodes; test-lab.sh checks the
# package set of every node after reset.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 8 [user]
run_as_student <<'STEPS'
# load-config.sh reads unset variables
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
rn() { run_on_node "$@" </dev/null; }

# Step 1
N1=$(get_node_ip 1); N2=$(get_node_ip 2)

# Step 2
rn "$N1" "rpm -q samba policycoreutils-python-utils ||
  sudo -n dnf -y install samba policycoreutils-python-utils"
rn "$N2" "rpm -q cifs-utils || sudo -n dnf -y install cifs-utils"

# Step 3
printf '%s\n' "" "[team]" \
  "        path = /srv/samba/team" \
  "        writable = yes" \
  "        valid users = @smbteam" |
  run_on_node "$N1" "sudo -n tee -a /etc/samba/smb.conf"
rn "$N1" "testparm -s --section-name=team"

# Step 4
rn "$N1" "sudo -n semanage fcontext -a \
  -t samba_share_t '/srv/samba/team(/.*)?'"
rn "$N1" "sudo -n restorecon -Rv /srv/samba/team"

# Step 5
printf '%s\n' Smb.Team.2468 Smb.Team.2468 |
  run_on_node "$N1" "sudo -n smbpasswd -s -a smbuser"
rn "$N1" "sudo -n pdbedit -L"

# Step 6
rn "$N1" "sudo -n systemctl enable --now smb"
rn "$N1" "sudo -n firewall-cmd --permanent --add-service=samba"
rn "$N1" "sudo -n firewall-cmd --reload"

# Step 7
printf '%s\n' username=smbuser password=Smb.Team.2468 |
  run_on_node "$N2" "sudo -n sh -c 'umask 077; cat > /root/team.creds'"
rn "$N2" "sudo -n ls -l /root/team.creds"

# Step 8
rn "$N2" "sudo -n mkdir -p /mnt/team"
OPTS=credentials=/root/team.creds,_netdev
echo "//$N1/team /mnt/team cifs $OPTS 0 0" |
  run_on_node "$N2" "sudo -n tee -a /etc/fstab"
rn "$N2" "sudo -n systemctl daemon-reload"
rn "$N2" "sudo -n mount /mnt/team"
STEPS
