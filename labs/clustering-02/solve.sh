#!/bin/bash
# Reference solution for clustering-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The steps run on the cluster nodes through run_on_node.
#
# solve: none
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

NODE1_IP=$(get_node_ip 1)

# Step 1 [sudo] install the fence agents on all nodes
for n in 1 2 3; do
	run_on_node "$(get_node_ip "$n")" "sudo dnf -y install --enablerepo=ha fence-agents-all"
done

# Steps 2 and 3 [sudo] one fence device per node, named after its node
for n in 1 2 3; do
	name=$(run_on_node "$(get_node_ip "$n")" "sudo crm_node -n")
	run_on_node "$NODE1_IP" "sudo pcs stonith create stonith-node$n fence_virsh ipaddr=127.0.0.1 login=root pcmk_host_list=$name meta migration-threshold=INFINITY"
done

# Step 4 [sudo] enable fencing
run_on_node "$NODE1_IP" "sudo pcs property set stonith-enabled=true"

# Step 5 [sudo] show the cluster status
run_on_node "$NODE1_IP" "sudo pcs status"
