#!/bin/bash
# Reference solution for clustering-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# The steps run as the lab user on the workstation and reach the nodes
# with run_on_node. Every run_on_node call reads nothing from standard
# input (< /dev/null), because ssh would otherwise consume the step script.
# The nodes' state cannot be declared here, so no path or package is listed.
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

# Step 1
N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
ALL="$N1 $N2 $N3"
H1=$(run_on_node "$N1" uname -n </dev/null)
H2=$(run_on_node "$N2" uname -n </dev/null)
H3=$(run_on_node "$N3" uname -n </dev/null)

# Step 2
EL=$(run_on_node "$N1" '. /etc/os-release; echo ${VERSION_ID%%.*}' </dev/null)
if [ "$EL" = 8 ]; then HA_REPO=ha; else HA_REPO=highavailability; fi
for ip in $ALL; do
  run_on_node "$ip" "sudo dnf -y install --enablerepo=$HA_REPO pacemaker pcs httpd" </dev/null
done

# Step 3
for ip in $ALL; do
  run_on_node "$ip" "
    sudo firewall-cmd --permanent --add-service=high-availability &&
    sudo firewall-cmd --reload &&
    echo 'hacluster:LabPass-2024' | sudo chpasswd &&
    sudo systemctl enable --now pcsd" </dev/null
done

# Step 4
NODES="$H1 addr=$N1 $H2 addr=$N2 $H3 addr=$N3"
run_on_node "$N1" \
  "sudo pcs host auth $NODES -u hacluster -p LabPass-2024" </dev/null
run_on_node "$N1" \
  "sudo pcs cluster setup ha_cluster $NODES --start --enable" </dev/null

# Step 5: wait for quorum (up to 2 minutes), then disable STONITH
for _ in $(seq 60); do
  [ "$(run_on_node "$N1" "sudo crm_node -q" </dev/null)" = 1 ] && break
  sleep 2
done
run_on_node "$N1" "sudo pcs property set stonith-enabled=false" </dev/null

# Step 6
for ip in $ALL; do
  run_on_node "$ip" "
    echo \"HA Cluster - \$(uname -n)\" |
      sudo tee /var/www/html/index.html >/dev/null
    sudo systemctl disable httpd" </dev/null
done

# Step 7, then wait for the resource to start (up to 2 minutes)
run_on_node "$N1" "sudo pcs resource create apache_web \
  ocf:heartbeat:apache configfile=/etc/httpd/conf/httpd.conf \
  op monitor interval=1min" </dev/null
for _ in $(seq 60); do
  run_on_node "$N1" "sudo crm_mon -1 -r" </dev/null | grep -Eq 'apache_web.*Started' && break
  sleep 2
done
STEPS
