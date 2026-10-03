#!/bin/bash
# storage-09 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

LAB=storage-09
STATE_FILE=/opt/linux-labs/state/$LAB
IQN=iqn.2026-10.lab.example:storage
INIT=iqn.2026-10.lab.example:node2
IMG=/srv/iscsi/disk1.img
MP=/mnt/iscsi

grade_begin storage-09
grade_require_state storage-09 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# Node 1: one line per fact that holds. The saved configuration is
# read with Python, which targetcli needs anyway (platform-python on
# Rocky Linux 8).
NODE1=$(run_on_node "$N1" "sudo -n bash -s -- $IQN $INIT $IMG $N1" 2>/dev/null <<'REMOTE'
iqn=$1 init=$2 img=$3 n1=$4
py=$(command -v python3 || echo /usr/libexec/platform-python)
if [ -r /etc/target/saveconfig.json ]; then
	"$py" - "$iqn" "$init" "$img" <<'PY' 2>/dev/null
import json
import os
import sys

iqn, init, img = sys.argv[1:4]
with open("/etc/target/saveconfig.json") as f:
    cfg = json.load(f)
names = []
for so in cfg.get("storage_objects", []):
    if so.get("plugin") != "fileio":
        continue
    if os.path.normpath(so.get("dev", "")) != img:
        continue
    names.append("/backstores/fileio/" + so.get("name", ""))
    if int(so.get("size", 0)) == 512 * 1024 * 1024:
        print("backstore")
for t in cfg.get("targets", []):
    if t.get("wwn") != iqn or t.get("fabric", "iscsi") != "iscsi":
        continue
    print("target")
    for tpg in t.get("tpgs", []):
        lun0 = [l for l in tpg.get("luns", []) if l.get("index") == 0]
        if lun0 and lun0[0].get("storage_object") in names:
            print("lun0")
        for acl in tpg.get("node_acls", []):
            if acl.get("node_wwn") != init:
                continue
            if any(m.get("tpg_lun") == 0 for m in acl.get("mapped_luns", [])):
                print("acl")
        for p in tpg.get("portals", []):
            if int(p.get("port", 0)) == 3260:
                print("portal")
PY
fi
systemctl is-enabled --quiet target 2>/dev/null && echo enabled
[ -n "$(ss -Hltn sport = :3260 2>/dev/null)" ] && echo listening

# fw_allows [--permanent]: the zone of the interface with the node 1
# address (or the default zone) has port 3260/tcp, or a service with it
fw_allows() {
	local iface zone s
	iface=$(ip -o -4 addr show | awk -v a="$n1" '{ split($4, x, "/"); if (x[1] == a) print $2 }')
	zone=
	[ -n "$iface" ] && zone=$(firewall-cmd "$@" --get-zone-of-interface="$iface" 2>/dev/null)
	[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone 2>/dev/null)
	firewall-cmd "$@" --zone="$zone" --query-port=3260/tcp >/dev/null 2>&1 && return 0
	for s in $(firewall-cmd "$@" --zone="$zone" --list-services 2>/dev/null); do
		firewall-cmd "$@" --info-service="$s" 2>/dev/null |
			grep -E '^[[:space:]]+ports:' |
			grep -Eq '(:|[[:space:]])3260/tcp([[:space:]]|$)' && return 0
	done
	return 1
}
fw_allows && echo fw-runtime
fw_allows --permanent && echo fw-permanent
exit 0
REMOTE
)

# Node 2
NODE2=$(run_on_node "$N2" "sudo -n bash -s -- $IQN $INIT $N1 $MP" 2>/dev/null <<'REMOTE'
iqn=$1 init=$2 n1=$3 mp=$4

name=$(sed -n 's/^[[:space:]]*InitiatorName[[:space:]]*=[[:space:]]*//p' /etc/iscsi/initiatorname.iscsi 2>/dev/null | tail -n 1)
[ "$name" = "$init" ] && echo initiator

command -v iscsiadm >/dev/null 2>&1 || exit 0

iscsiadm -m session 2>/dev/null |
	awk -v p="$n1:3260," -v t="$iqn" 'index($3, p) == 1 && $4 == t { f = 1 } END { exit !f }' &&
	echo session

iscsiadm -m node -T "$iqn" -p "$n1:3260" -o show 2>/dev/null |
	grep -Eq '^node\.startup[[:space:]]*=[[:space:]]*automatic[[:space:]]*$' &&
	echo startup

# The disk of LUN 0 of the lab target, as udev names it by path
lun=
for l in /dev/disk/by-path/ip-*-iscsi-"$iqn"-lun-0; do
	[ -e "$l" ] && lun=$(readlink -f "$l") && break
done
[ -n "$lun" ] || exit 0
lunk=$(lsblk -dno KNAME "$lun" 2>/dev/null)

# Mounted: XFS whose device is the LUN or lies on it
src=$(findmnt -n -o SOURCE --mountpoint "$mp" 2>/dev/null | tail -n 1)
fstype=$(findmnt -n -o FSTYPE --mountpoint "$mp" 2>/dev/null | tail -n 1)
if [ -n "$src" ] && [ "$fstype" = xfs ] &&
	lsblk -s -n -o KNAME "$src" 2>/dev/null | awk '{ print $1 }' | grep -qx "$lunk"; then
	echo mounted
fi

# fstab: UUID of a file system on the LUN, xfs, _netdev and nofail
uuids=$(lsblk -n -o UUID "$lun" 2>/dev/null | awk 'NF')
awk -v m="$mp" -v u="$(printf '%s ' $uuids)" '
	BEGIN { n = split(u, a, " "); for (i = 1; i <= n; i++) ok["UUID=" a[i]] = 1 }
	$1 !~ /^#/ && ($2 == m || $2 == m "/") {
		s = $1; gsub(/"/, "", s)
		o = "," $4 ","
		if ((s in ok) && $3 == "xfs" && o ~ /,_netdev,/ && o ~ /,nofail,/) f = 1
	}
	END { exit !f }' /etc/fstab && echo fstab

findmnt --verify >/dev/null 2>&1 && echo verify
exit 0
REMOTE
)

# has <node output> <fact>
has() {
	printf '%s\n' "$1" | grep -qx "$2"
}

criterion "Node 1 config: fileio backstore $IMG, 512 MiB" has "$NODE1" backstore
criterion "Node 1 config: target $IQN" has "$NODE1" target
criterion "Node 1 config: LUN 0 of the target uses that backstore" has "$NODE1" lun0
criterion "Node 1 config: ACL for $INIT with LUN 0" has "$NODE1" acl
criterion "Node 1 config: a portal on port 3260" has "$NODE1" portal
criterion "target.service is enabled on node 1" has "$NODE1" enabled
criterion "Node 1 listens on port 3260/tcp" has "$NODE1" listening
criterion "The node 1 runtime firewall allows 3260/tcp" has "$NODE1" fw-runtime
criterion "The node 1 permanent firewall allows 3260/tcp" has "$NODE1" fw-permanent
criterion "The initiator name of node 2 is $INIT" has "$NODE2" initiator
criterion "Node 2 has a session to $IQN" has "$NODE2" session
criterion "The node 2 record of the target logs in at boot" has "$NODE2" startup
criterion "$MP on node 2 is XFS on LUN 0 of the target" has "$NODE2" mounted
criterion "/etc/fstab on node 2 mounts $MP by UUID, _netdev, nofail" has "$NODE2" fstab
criterion "findmnt --verify on node 2 reports no errors" has "$NODE2" verify
grade_end
