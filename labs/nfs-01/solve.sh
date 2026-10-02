#!/bin/bash
# Reference solution for nfs-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# The steps run as the lab user on the workstation and reach the nodes
# with run_on_node. Every run_on_node call that needs no input reads
# /dev/null, because ssh would otherwise consume the step script.
# The package is installed on the nodes; test-lab.sh checks the package
# set of every node after reset.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 6 [user]
run_as_student <<'STEPS'
# load-config.sh reads unset variables
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
rn() { run_on_node "$@" </dev/null; }

# Step 1
N1=$(get_node_ip 1); N2=$(get_node_ip 2)

# Step 2
for ip in $N1 $N2; do
  rn "$ip" "rpm -q nfs-utils || sudo -n dnf -y install nfs-utils"
done

# Step 3
rn "$N1" "sudo -n chown nobody:nobody /srv/nfsshare"
echo "/srv/nfsshare $N2(rw)" | run_on_node "$N1" \
  "sudo -n tee /etc/exports.d/nfsshare.exports"

# Step 4
rn "$N1" "sudo -n systemctl enable --now nfs-server"
rn "$N1" "sudo -n exportfs -rv"

# Step 5
rn "$N1" "sudo -n firewall-cmd --permanent --add-service=nfs"
rn "$N1" "sudo -n firewall-cmd --reload"

# Step 6
rn "$N2" "sudo -n mkdir -p /mnt/nfsshare"
echo "$N1:/srv/nfsshare /mnt/nfsshare nfs defaults,_netdev 0 0" |
  run_on_node "$N2" "sudo -n tee -a /etc/fstab"
rn "$N2" "sudo -n systemctl daemon-reload"
rn "$N2" "sudo -n mount /mnt/nfsshare"
STEPS
