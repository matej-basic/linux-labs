#!/bin/bash
# clustering-01 cleanup: destroys the cluster on the three nodes and
# removes the packages, files and firewall rule that the lab or its
# solution added. Packages and rules that were there before the lab
# started (recorded by setup.sh) stay.
set -e
# load-config.sh reads unset variables, so it is sourced before set -u
source /opt/linux-labs/lib/load-config.sh
set -u

LAB=clustering-01
STATE_FILE="/opt/linux-labs/state/$LAB"

# Run a script on a node as root. The script travels base64-encoded in the
# command line, so its standard input stays free for the programs in it.
run_script() {
	local ip="$1" script="$2" b64
	shift 2
	b64=$(printf '%s' "$script" | base64 | tr -d '\n')
	run_on_node "$ip" "sudo bash -c \"\$(echo $b64 | base64 -d)\" _ $*" </dev/null
}

# Without multi-node configuration there is nothing to undo
if [ "$NODES_ENABLED" != true ] || [ "$NODE_COUNT" -lt 3 ]; then
	rm -f "$STATE_FILE"
	exit 0
fi

# Arguments: $1 = 1 removes httpd, $2 = 1 removes the firewall service
# shellcheck disable=SC2016 # the script is meant to expand on the node
CLEAN='
rm_httpd=${1:-0}
rm_fw=${2:-0}
if command -v pcs >/dev/null 2>&1; then pcs cluster destroy >/dev/null 2>&1 || true; fi
systemctl disable --now pacemaker corosync pcsd >/dev/null 2>&1 || true
if [ "$rm_httpd" = 1 ]; then
	pkill -x httpd >/dev/null 2>&1 || true
	rm -f /var/www/html/index.html
	dnf -y -q remove httpd >/dev/null 2>&1 || true
elif grep -qs "HA Cluster" /var/www/html/index.html; then
	rm -f /var/www/html/index.html
fi
dnf -y -q remove pacemaker corosync pcs >/dev/null 2>&1 || true
if [ "$rm_fw" = 1 ] && command -v firewall-cmd >/dev/null 2>&1 &&
	firewall-cmd --state >/dev/null 2>&1; then
	firewall-cmd --permanent --remove-service=high-availability >/dev/null 2>&1 || true
	firewall-cmd --reload >/dev/null 2>&1 || true
fi
rm -f /etc/corosync/corosync.conf /etc/corosync/authkey
rm -f /var/lib/pcsd/known-hosts /var/lib/pcsd/tokens /var/lib/pcsd/pcs_settings.conf
rm -rf /var/lib/pacemaker/cib/* /var/lib/pacemaker/pengine/* /var/lib/corosync/*
if id hacluster >/dev/null 2>&1; then passwd -l hacluster >/dev/null 2>&1 || true; fi
exit 0
'

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	rm_httpd=0
	rm_fw=0
	grep -qx "node${n}_httpd=absent" "$STATE_FILE" 2>/dev/null && rm_httpd=1
	grep -qx "node${n}_hafw=absent" "$STATE_FILE" 2>/dev/null && rm_fw=1
	if ! test_node_connectivity "$ip" >/dev/null 2>&1; then
		echo "Error: node $n ($ip) is not reachable over SSH, not cleaned" >&2
		rc=1
		continue
	fi
	run_script "$ip" "$CLEAN" "$rm_httpd" "$rm_fw" >/dev/null 2>&1 || {
		echo "Error: cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
