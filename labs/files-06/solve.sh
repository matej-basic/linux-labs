#!/bin/bash
# Reference solution for files-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Everything happens on the nodes, which labctl reset puts back and
# test-lab.sh checks (package set, rsync included); no path or package
# on the workstation needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: the workstation logs in to node 1 as opsadmin.
# Steps 2 to 5 [sudo] run on node 1. Host keys are accepted without a
# prompt, the only difference to solution.md.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

run_on_node "$N1" "N2='$N2' bash -euo pipefail -s" <<'NODE1'
SSH='ssh -o StrictHostKeyChecking=accept-new -i /home/opsadmin/.ssh/id_ed25519'

# Step 2
rpm -q rsync >/dev/null || sudo dnf -y install rsync >/dev/null
$SSH "$N2" 'rpm -q rsync >/dev/null || sudo dnf -y install rsync >/dev/null' </dev/null

# Step 3
sudo tar -C /srv -cJf /srv/projects.tar.xz projects
sudo tar -tvJf /srv/projects.tar.xz >/dev/null

# Step 4
sudo rsync -a --exclude='*.tmp' -e "$SSH" --rsync-path='sudo rsync' \
  /srv/projects "opsadmin@$N2:/srv/backup/" </dev/null

# Step 5
sudo tar -C /srv/restore -xJf /srv/projects.tar.xz
NODE1
STEPS
