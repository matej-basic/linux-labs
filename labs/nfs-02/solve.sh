#!/bin/bash
# Reference solution for nfs-02, the same steps as solution.md.
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
rn "$N1" "rpm -q nfs-utils || sudo -n dnf -y install nfs-utils"
rn "$N2" \
  "rpm -q nfs-utils autofs || sudo -n dnf -y install nfs-utils autofs"

# Step 3
printf '%s\n' \
  "/srv/projects $N2(rw,all_squash,anonuid=3001,anongid=3001)" \
  "/srv/docs $N2(ro)" |
  run_on_node "$N1" "sudo -n tee /etc/exports.d/nfs-02.exports"

# Step 4
rn "$N1" "sudo -n systemctl enable --now nfs-server"
rn "$N1" "sudo -n exportfs -rv"

# Step 5
rn "$N1" "sudo -n firewall-cmd --permanent --add-service=nfs"
rn "$N1" "sudo -n firewall-cmd --reload"

# Step 6
echo "/shares /etc/auto.shares" |
  run_on_node "$N2" "sudo -n tee /etc/auto.master.d/shares.autofs"
printf '%s\n' \
  "projects -rw $N1:/srv/projects" \
  "docs -ro $N1:/srv/docs" |
  run_on_node "$N2" "sudo -n tee /etc/auto.shares"

# Step 7
rn "$N2" "sudo -n systemctl enable autofs"
rn "$N2" "sudo -n systemctl restart autofs"
STEPS
