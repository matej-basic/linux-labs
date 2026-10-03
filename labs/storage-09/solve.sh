#!/bin/bash
# Reference solution for storage-09, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Everything happens on the nodes, which labctl reset puts back and
# test-lab.sh checks (package set, system users); no path or package on
# the workstation needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 6 [user]: the workstation logs in to the nodes as the
# node account. Steps 2 to 5 [sudo] run on node 1, steps 7 to 9 [sudo]
# on node 2.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -u
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

run_on_node "$N1" "bash -euo pipefail -s" <<'NODE1'
# Step 2
rpm -q targetcli >/dev/null || sudo dnf -y install targetcli </dev/null >/dev/null
sudo systemctl enable --now target </dev/null >/dev/null 2>&1

# Step 3
sudo mkdir -p /srv/iscsi
sudo targetcli /backstores/fileio create disk1 \
  /srv/iscsi/disk1.img 512M </dev/null >/dev/null
sudo targetcli /iscsi create iqn.2026-10.lab.example:storage </dev/null >/dev/null
T=/iscsi/iqn.2026-10.lab.example:storage/tpg1
sudo targetcli $T/luns create /backstores/fileio/disk1 </dev/null >/dev/null
sudo targetcli $T/acls create iqn.2026-10.lab.example:node2 </dev/null >/dev/null

# Step 4
sudo targetcli saveconfig </dev/null >/dev/null
sudo ss -ltn sport = :3260 | grep -q 3260

# Step 5
sudo firewall-cmd --add-service=iscsi-target >/dev/null
sudo firewall-cmd --permanent --add-service=iscsi-target >/dev/null
NODE1

run_on_node "$N2" "N1='$N1' bash -euo pipefail -s" <<'NODE2'
# Step 7
rpm -q iscsi-initiator-utils >/dev/null ||
  sudo dnf -y install iscsi-initiator-utils </dev/null >/dev/null
echo "InitiatorName=iqn.2026-10.lab.example:node2" |
  sudo tee /etc/iscsi/initiatorname.iscsi >/dev/null
sudo systemctl restart iscsid </dev/null

# Step 8
IQN=iqn.2026-10.lab.example:storage
sudo iscsiadm -m discovery -t sendtargets -p "$N1" </dev/null >/dev/null
sudo iscsiadm -m node -T $IQN -p "$N1" -l </dev/null >/dev/null
sudo iscsiadm -m node -T $IQN -p "$N1" \
  -o update -n node.startup -v automatic </dev/null
sudo iscsiadm -m session </dev/null >/dev/null

# Step 9
DISK=/dev/disk/by-path/ip-$N1:3260-iscsi-$IQN-lun-0
sudo udevadm settle
sudo mkfs.xfs -q $DISK </dev/null
UUID=$(sudo blkid -s UUID -o value $DISK)
sudo mkdir -p /mnt/iscsi
echo "UUID=$UUID /mnt/iscsi xfs _netdev,nofail 0 0" |
  sudo tee -a /etc/fstab >/dev/null
sudo mount /mnt/iscsi </dev/null
sudo systemctl daemon-reload </dev/null
sudo findmnt --verify </dev/null >/dev/null
NODE2
STEPS
