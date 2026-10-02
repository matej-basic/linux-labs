#!/bin/bash
# Reference solution for clustering-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The steps run on the cluster nodes through run_on_node. The package is
# installed on the nodes; test-lab.sh checks the package set of every node
# after reset.
#
# solve: package fence-agents-virsh
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

NODE1_IP=$(get_node_ip 1)

# Step 1 [sudo] install the fence agent on all nodes
# shellcheck disable=SC2016 # expanded on the node
EL=$(run_on_node "$NODE1_IP" '. /etc/os-release; echo ${VERSION_ID%%.*}' </dev/null)
if [ "$EL" = 8 ]; then HA_REPO=ha; else HA_REPO=highavailability; fi
for n in 1 2 3; do
	run_on_node "$(get_node_ip "$n")" "rpm -q fence-agents-virsh >/dev/null ||
		sudo -n dnf -y install --enablerepo=$HA_REPO fence-agents-virsh" </dev/null
done

# Steps 2 and 3 [sudo] one fence device per node, named after its node
for n in 1 2 3; do
	name=$(run_on_node "$(get_node_ip "$n")" "sudo -n crm_node -n" </dev/null)
	run_on_node "$NODE1_IP" "sudo -n pcs stonith create stonith-node$n fence_virsh ipaddr=127.0.0.1 login=root pcmk_host_list=$name meta migration-threshold=INFINITY" </dev/null
done

# Step 4 [sudo] enable fencing
run_on_node "$NODE1_IP" "sudo -n pcs property set stonith-enabled=true" </dev/null

# Step 5 [sudo] show the cluster status
run_on_node "$NODE1_IP" "sudo -n pcs status" </dev/null
