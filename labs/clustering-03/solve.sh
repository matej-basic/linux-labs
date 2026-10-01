#!/bin/bash
# Reference solution for clustering-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 5 [user]
run_as_student <<'STEPS'
# load-config.sh is not safe under "set -u"
set +u
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -u
NODES="$(get_node_ip 1) $(get_node_ip 2) $(get_node_ip 3)"
NODE1=$(get_node_ip 1)
CONF=/etc/corosync/corosync.conf
n() { local ip=$1; shift; ssh -n "$SSH_USER@$ip" "$@"; }

# Step 2
for ip in $NODES; do n "$ip" "sudo corosync-quorumtool -s" >/dev/null; done

# Step 3
DEL='/^[[:space:]]*(wait_for_all|last_man_standing|'
DEL="$DEL"'last_man_standing_window):/d'
ADD='/^quorum {/,/^}/ s/^\([[:space:]]*\)provider:.*/&'
ADD="$ADD"'\n\1wait_for_all: 1\n\1last_man_standing: 1'
ADD="$ADD"'\n\1last_man_standing_window: 10000/'
for ip in $NODES; do
  n "$ip" "sudo sed -i -E '$DEL' $CONF"
  n "$ip" "sudo sed -i '$ADD' $CONF"
done

# Step 4
for ip in $NODES; do
  n "$ip" "sudo systemctl stop pacemaker corosync"
  n "$ip" "sudo systemctl start pacemaker"
  for i in $(seq 1 60); do
    n "$ip" "sudo corosync-quorumtool -s |
      grep -Eq '^Nodes:[[:space:]]+3\$'" && break
    sleep 2
  done
done

# Step 5: retry while the cluster elects a DC again
for i in $(seq 1 30); do
  n "$NODE1" "sudo pcs property set no-quorum-policy=stop" && break
  sleep 2
done
STEPS
