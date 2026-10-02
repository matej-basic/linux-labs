#!/bin/bash
# nfs-01 cleanup: puts nodes 1 and 2 back into the state that the first
# setup.sh run recorded. Node 2 goes first: the NFS mount and its fstab
# line are removed while node 1 still serves the export. On node 1 the
# export, the NFS firewall services and /srv/nfsshare go. Where the lab
# installed nfs-utils or rpcbind, their services stop and their state
# directories go, so that the accounts rpcuser and rpc own no file; then
# the package set of the first start comes back (lib/packages.sh), which
# removes the packages together with those accounts. Where nfs-utils was
# there before, /etc/exports and the state of nfs-server come back as
# recorded. When a node cannot be restored, its records stay for the
# next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=nfs-01
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Shared by both nodes, before the package restore: stop the NFS and RPC
# services and remove the state directories of the packages the lab
# installed. Without a package snapshot nothing is removed.
cat > "$tmp/rpc.sh" <<'REMOTE'
snap=/opt/linux-labs/state/nfs-01.packages/packages

new_pkg() {
	[ -s "$snap" ] && rpm -q "$1" >/dev/null 2>&1 && ! grep -q "^$1\." "$snap"
}

if new_pkg nfs-utils; then
	systemctl disable --now nfs-server </dev/null >/dev/null 2>&1
	systemctl stop nfs-server nfs-mountd nfs-idmapd nfsdcld rpc-statd \
		rpc-statd-notify rpc-gssd gssproxy nfs-blkmap nfs-client.target \
		</dev/null >/dev/null 2>&1
	systemctl stop var-lib-nfs-rpc_pipefs.mount proc-fs-nfsd.mount \
		</dev/null >/dev/null 2>&1
	mountpoint -q /var/lib/nfs/rpc_pipefs 2>/dev/null &&
		umount -l /var/lib/nfs/rpc_pipefs </dev/null >/dev/null 2>&1
	if mountpoint -q /var/lib/nfs/rpc_pipefs 2>/dev/null; then
		echo "cannot unmount /var/lib/nfs/rpc_pipefs" >&2
		exit 1
	fi
	rm -rf --one-file-system /var/lib/nfs
fi
if new_pkg rpcbind; then
	systemctl stop rpcbind.socket rpcbind </dev/null >/dev/null 2>&1
	rm -rf /var/lib/rpcbind
fi
if new_pkg gssproxy; then
	systemctl stop gssproxy </dev/null >/dev/null 2>&1
fi
exit 0
REMOTE

# Node 2 before the package restore: no mount, no fstab line
cat > "$tmp/client.sh" <<'REMOTE'
mp=/mnt/nfsshare

[ -f /opt/linux-labs/state/nfs-01.packages/packages ] || exit 0

if mountpoint -q "$mp" 2>/dev/null; then
	umount "$mp" </dev/null >/dev/null 2>&1 ||
		umount -f -l "$mp" </dev/null >/dev/null 2>&1
fi
if mountpoint -q "$mp" 2>/dev/null; then
	echo "cannot unmount $mp" >&2
	exit 1
fi
if awk -v m="$mp" '$1 !~ /^#/ && ($2 == m || $2 == m "/") { f = 1 } END { exit !f }' /etc/fstab; then
	awk -v m="$mp" '$1 ~ /^#/ || ($2 != m && $2 != m "/")' /etc/fstab > /etc/fstab.nfs-01 || exit 1
	cat /etc/fstab.nfs-01 > /etc/fstab || exit 1
	rm -f /etc/fstab.nfs-01
fi
systemctl daemon-reload </dev/null >/dev/null 2>&1
rm -rf --one-file-system "$mp"
exit 0
REMOTE

# Node 1 before the package restore: no export, firewall as recorded,
# no lab directory
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/nfs-01.pre
dir=/srv/nfsshare

# setup.sh never recorded this node: nothing to undo
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

for f in /etc/exports /etc/exports.d/*.exports; do
	[ -f "$f" ] || continue
	if awk -v d="$dir" '$1 == d || $1 == d "/" { f = 1 } END { exit !f }' "$f"; then
		awk -v d="$dir" '$1 != d && $1 != d "/"' "$f" > "$f.nfs-01" || exit 1
		cat "$f.nfs-01" > "$f" || exit 1
		rm -f "$f.nfs-01"
	fi
	# An exports file the solution created and that is now empty
	case "$f" in
	/etc/exports.d/*)
		if ! grep -q '[^[:space:]]' "$f" && ! rpm -qf "$f" >/dev/null 2>&1; then
			rm -f "$f"
		fi
		;;
	esac
done
if systemctl is-active --quiet nfs-server; then
	exportfs -ra </dev/null >/dev/null 2>&1
fi

if systemctl is-active --quiet firewalld; then
	for s in nfs mountd rpc-bind; do
		if had "fw-$s"; then
			firewall-cmd --permanent --add-service="$s" </dev/null >/dev/null 2>&1
		else
			firewall-cmd --permanent --remove-service="$s" </dev/null >/dev/null 2>&1
		fi
	done
	firewall-cmd --reload </dev/null >/dev/null 2>&1
fi

rm -rf --one-file-system "$dir"
exit 0
REMOTE

# Node 1 after the package restore: exports file and nfs-server as
# recorded where nfs-utils was there before the lab
cat > "$tmp/server-post.sh" <<'REMOTE'
pre=/var/tmp/nfs-01.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if [ -f "$pre/exports" ]; then
	cat "$pre/exports" > /etc/exports
fi
if systemctl cat nfs-server </dev/null >/dev/null 2>&1; then
	if had nfs-server-enabled; then
		systemctl enable nfs-server </dev/null >/dev/null 2>&1
	else
		systemctl disable nfs-server </dev/null >/dev/null 2>&1
	fi
	if had nfs-server-active; then
		systemctl start nfs-server </dev/null >/dev/null 2>&1
		exportfs -ra </dev/null >/dev/null 2>&1
	else
		systemctl stop nfs-server </dev/null >/dev/null 2>&1
	fi
fi
rm -f /etc/exports.rpmsave
rm -rf "$pre"
exit 0
REMOTE

rc=0
# Client first, so that the mount goes while the server still answers
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if [ "$n" = 2 ]; then
		cat "$tmp/client.sh" > "$tmp/stop.sh"
	else
		cat "$tmp/server.sh" > "$tmp/stop.sh"
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" > "$tmp/out" 2>&1 ||
		! run_on_node "$ip" "sudo -n bash -s" < "$tmp/rpc.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" "$LAB" 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	if [ "$n" = 1 ] && ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/server-post.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
