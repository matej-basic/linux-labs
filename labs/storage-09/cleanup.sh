#!/bin/bash
# storage-09 cleanup: puts nodes 1 and 2 back into the state that the
# first setup.sh run recorded in /var/tmp/storage-09.pre on each node.
# Node 2 goes first, while node 1 still serves the LUN: the file system
# at /mnt/iscsi is unmounted, its fstab line goes, the sessions to the
# lab target are logged out and the node and discovery records of the
# lab are deleted. On node 1 the running target configuration is
# cleared, /etc/target comes back as recorded, /srv/iscsi and the
# targetcli history go, and the firewall ports and services added since
# the first start are removed (runtime and permanent). Then the package
# set of the first start comes back on each node (lib/packages.sh), and
# last the leftovers of removed packages (/etc/iscsi, /var/lib/iscsi,
# /etc/target) go, or the initiator name and target.service come back
# as recorded where the packages were there before the lab.
# A node without records was never prepared and is left alone. When a
# node cannot be restored, its records stay for the next reset and the
# exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=storage-09
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

N1=$(get_node_ip 1)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 2 before the package restore. $1 is the address of node 1.
cat > "$tmp/node2.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre
iqn=iqn.2026-10.lab.example:storage
mp=/mnt/iscsi
n1=$1

[ -d "$pre" ] || exit 0

if mountpoint -q "$mp" 2>/dev/null; then
	timeout 60 umount "$mp" </dev/null >/dev/null 2>&1 ||
		umount -l "$mp" </dev/null >/dev/null 2>&1
fi
if mountpoint -q "$mp" 2>/dev/null; then
	echo "cannot unmount $mp" >&2
	exit 1
fi
if awk -v m="$mp" '$1 !~ /^#/ && ($2 == m || $2 == m "/") { f = 1 } END { exit !f }' /etc/fstab; then
	awk -v m="$mp" '$1 ~ /^#/ || ($2 != m && $2 != m "/")' /etc/fstab > /etc/fstab.storage-09 || exit 1
	cat /etc/fstab.storage-09 > /etc/fstab || exit 1
	rm -f /etc/fstab.storage-09
fi
systemctl daemon-reload </dev/null >/dev/null 2>&1
if ! grep -qx mnt-existed "$pre/flags" 2>/dev/null; then
	rm -rf --one-file-system "$mp"
fi

if command -v iscsiadm >/dev/null 2>&1; then
	# Log out of every portal of the lab target, then forget it
	iscsiadm -m node -T "$iqn" -u </dev/null >/dev/null 2>&1
	if iscsiadm -m session </dev/null 2>/dev/null | awk -v t="$iqn" '$4 == t { f = 1 } END { exit !f }'; then
		echo "cannot log out of the target $iqn" >&2
		exit 1
	fi
	iscsiadm -m node -T "$iqn" -o delete </dev/null >/dev/null 2>&1
	# Discovery records of node 1, by address or host name
	iscsiadm -m discoverydb </dev/null 2>/dev/null | while read -r portal method; do
		host=${portal%:*}
		if [ "$host" != "$n1" ]; then
			addr=$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR == 1 { print $1 }')
			[ "$addr" = "$n1" ] || continue
		fi
		iscsiadm -m discoverydb -t "${method#via }" -p "$portal" -o delete </dev/null >/dev/null 2>&1
	done
fi
exit 0
REMOTE

# Node 2 after the package restore: the leftovers of a package the lab
# installed, or the recorded initiator name
cat > "$tmp/node2-post.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if rpm -q iscsi-initiator-utils >/dev/null 2>&1; then
	if [ -f "$pre/initiatorname.iscsi" ]; then
		cp -a "$pre/initiatorname.iscsi" /etc/iscsi/initiatorname.iscsi || exit 1
	else
		rm -f /etc/iscsi/initiatorname.iscsi
	fi
	if systemctl is-active --quiet iscsid; then
		systemctl restart iscsid </dev/null >/dev/null 2>&1
	fi
else
	had etc-iscsi-existed || rm -rf /etc/iscsi
	had var-iscsi-existed || rm -rf /var/lib/iscsi
fi
rm -rf "$pre"
exit 0
REMOTE

# Node 1 before the package restore
cat > "$tmp/node1.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre
rc=0

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

fw_dump() {
	firewall-cmd "$@" --list-all-zones | awk '
		/^[^ \t]/ { zone = $1 }
		/^[ \t]+services:/ { for (i = 2; i <= NF; i++) print zone, "service", $i }
		/^[ \t]+ports:/ { for (i = 2; i <= NF; i++) print zone, "port", $i }
	' | LC_ALL=C sort
}

# fw_restore <recorded file> [--permanent]
fw_restore() {
	local rec=$1 zone kind val
	shift
	[ -f "$rec" ] || return 0
	fw_dump "$@" > "$pre/fw.now" || return 1
	LC_ALL=C comm -13 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --remove-"$kind"="$val" >/dev/null
	done
	LC_ALL=C comm -23 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --add-"$kind"="$val" >/dev/null
	done
	fw_dump "$@" > "$pre/fw.now" || return 1
	cmp -s "$rec" "$pre/fw.now"
}

# The running target configuration, then the saved one
if command -v targetcli >/dev/null 2>&1; then
	targetcli clearconfig confirm=True </dev/null >/dev/null 2>&1 || {
		echo "targetcli clearconfig failed" >&2
		rc=1
	}
fi
systemctl stop target </dev/null >/dev/null 2>&1
rm -rf /etc/target
if [ -d "$pre/target" ]; then
	cp -a "$pre/target" /etc/target || rc=1
fi

if had srv-existed; then
	rm -f /srv/iscsi/disk1.img
else
	rm -rf --one-file-system /srv/iscsi
fi
had targetcli-home-existed || rm -rf /root/.targetcli

if firewall-cmd --state >/dev/null 2>&1; then
	fw_restore "$pre/fw.runtime" || { echo "firewall runtime rules not restored" >&2; rc=1; }
	fw_restore "$pre/fw.permanent" --permanent || { echo "firewall permanent rules not restored" >&2; rc=1; }
	rm -f "$pre/fw.now"
else
	echo "firewalld is not running, the firewall was not restored" >&2
	rc=1
fi
exit "$rc"
REMOTE

# Node 1 after the package restore: target.service as recorded where
# it is still installed, no leftover /etc/target where it is not
cat > "$tmp/node1-post.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if systemctl cat target </dev/null >/dev/null 2>&1; then
	if had target-enabled; then
		systemctl enable target </dev/null >/dev/null 2>&1
	else
		systemctl disable target </dev/null >/dev/null 2>&1
	fi
	if had target-active; then
		systemctl restart target </dev/null >/dev/null 2>&1 || exit 1
	fi
elif [ ! -d "$pre/target" ]; then
	rm -rf /etc/target
fi
rm -rf "$pre"
exit 0
REMOTE

rc=0
# Node 2 first, so that it logs out while node 1 still serves the LUN
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s -- $N1" < "$tmp/node$n.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
		continue
	fi
	if ! pkg_restore_node "$ip" "$LAB" 2> "$tmp/err"; then
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node$n-post.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
