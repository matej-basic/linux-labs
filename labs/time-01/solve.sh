#!/bin/bash
# Reference solution for time-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# The steps run as the lab user on the workstation and reach the nodes
# with run_on_node. Every run_on_node call that needs no input reads
# /dev/null, because ssh would otherwise consume the step script.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 7 [user]
run_as_student <<'STEPS'
# load-config.sh reads unset variables
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
rn() { run_on_node "$@" </dev/null; }

# Step 1
N1=$(get_node_ip 1); N2=$(get_node_ip 2)

# Step 2
printf 'allow %s\nlocal stratum 10\n' "$N2" |
  run_on_node "$N1" "sudo -n tee -a /etc/chrony.conf"

# Step 3
rn "$N1" "sudo -n systemctl enable chronyd"
rn "$N1" "sudo -n systemctl restart chronyd"

# Step 4
rn "$N1" "sudo -n firewall-cmd --permanent --add-service=ntp"
rn "$N1" "sudo -n firewall-cmd --reload"

# Step 5
rn "$N2" "sudo -n sed -i -E \
  's/^(pool|server|peer)[[:space:]]/#&/' /etc/chrony.conf"
echo "server $N1 iburst" |
  run_on_node "$N2" "sudo -n tee -a /etc/chrony.conf"

# Step 6
rn "$N2" "sudo -n systemctl enable chronyd"
rn "$N2" "sudo -n systemctl restart chronyd"

# Step 7
rn "$N2" "sudo -n timedatectl set-timezone Europe/Zagreb"
STEPS
