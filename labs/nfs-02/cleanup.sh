#!/bin/bash
# nfs-02 cleanup: puts nodes 1 and 2 back into the state that the first
# setup.sh run recorded. Node 2 goes first: autofs stops and its /shares
# map goes while node 1 still serves the exports. On node 1 the exports,
# the NFS firewall services, /srv/projects, /srv/docs and the user and
# group projdata go. Where the lab installed nfs-utils or rpcbind, their
# services stop and their state directories go, so that the accounts
# rpcuser and rpc own no file; then the package set of the first start
# comes back (lib/packages.sh), which removes the packages together with
# those accounts. Where nfs-utils or autofs were there before, the
# recorded /etc/exports and the recorded state of nfs-server and autofs
# come back. When a node cannot be restored, its records stay for the
# next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=nfs-02
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
snap=/opt/linux-labs/state/nfs-02.packages/packages

new_pkg() {
	[ -s "$snap" ] && rpm -q "$1" >/dev/null 2>&1 && ! grep -q "^$1\." "$snap"
}

if new_pkg autofs; then
	systemctl disable --now autofs </dev/null >/dev/null 2>&1
fi
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

# Node 2 before the package restore: the same helpers as setup.sh
cat > "$tmp/automap.sh" <<'REMOTE'
remove_shares_maps() {
	local f maps m
	maps=""
	for f in /etc/auto.master /etc/auto.master.d/*.autofs; do
		[ -f "$f" ] || continue
		if awk '$1 == "/shares" || $1 == "/shares/" { f = 1 } END { exit !f }' "$f"; then
			maps="$maps $(awk '$1 == "/shares" || $1 == "/shares/" { print $2 }' "$f")"
			awk '$1 != "/shares" && $1 != "/shares/"' "$f" > "$f.nfs-02" || return 1
			cat "$f.nfs-02" > "$f" || return 1
			rm -f "$f.nfs-02"
		fi
		# A master file the solution created and that is now empty
		case "$f" in
		/etc/auto.master.d/*)
			if ! grep -q '[^[:space:]]' "$f" && ! rpm -qf "$f" >/dev/null 2>&1; then
				rm -f "$f"
			fi
			;;
		esac
	done
	for m in $maps; do
		m=${m#file:}
		case "$m" in
		/etc/*)
			if [ -f "$m" ] && ! rpm -qf "$m" >/dev/null 2>&1; then
				rm -f "$m"
			fi
			;;
		esac
	done
	return 0
}

# Unmount everything below /shares and /shares itself
unmount_shares() {
	local m
	for m in $(findmnt -rn -o TARGET 2>/dev/null | awk '$1 ~ /^\/shares\// { print }' | sort -r); do
		umount "$m" </dev/null >/dev/null 2>&1 ||
			umount -f -l "$m" </dev/null >/dev/null 2>&1
	done
	if mountpoint -q /shares 2>/dev/null; then
		umount /shares </dev/null >/dev/null 2>&1 ||
			umount -l /shares </dev/null >/dev/null 2>&1
	fi
	if findmnt -rn -o TARGET 2>/dev/null | grep -q '^/shares\(/\|$\)'; then
		echo "cannot unmount /shares" >&2
		return 1
	fi
	return 0
}
REMOTE

# Node 2 before the package restore: no /shares map, autofs stopped,
# nothing mounted below /shares
cat > "$tmp/client.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre

# setup.sh never recorded this node: nothing to undo
[ -d "$pre" ] || exit 0

remove_shares_maps || exit 1
if systemctl cat autofs </dev/null >/dev/null 2>&1; then
	systemctl stop autofs </dev/null >/dev/null 2>&1
fi
unmount_shares || exit 1
rmdir /shares 2>/dev/null
exit 0
REMOTE

# Node 2 after the package restore: autofs as recorded where it was
# there before the lab
cat > "$tmp/client-post.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if systemctl cat autofs </dev/null >/dev/null 2>&1; then
	if had autofs-enabled; then
		systemctl enable autofs </dev/null >/dev/null 2>&1
	else
		systemctl disable autofs </dev/null >/dev/null 2>&1
	fi
	if had autofs-active; then
		systemctl start autofs </dev/null >/dev/null 2>&1
	else
		systemctl stop autofs </dev/null >/dev/null 2>&1
	fi
fi
if ! had autofs-installed; then
	rm -f /etc/auto.master.rpmsave
fi
rm -rf "$pre"
exit 0
REMOTE

# Node 1 before the package restore: no exports, firewall as recorded,
# no lab directories, no lab user and group
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

for f in /etc/exports /etc/exports.d/*.exports; do
	[ -f "$f" ] || continue
	if awk '$1 ~ /^\/srv\/(projects|docs)\/?$/ { f = 1 } END { exit !f }' "$f"; then
		awk '$1 !~ /^\/srv\/(projects|docs)\/?$/' "$f" > "$f.nfs-02" || exit 1
		cat "$f.nfs-02" > "$f" || exit 1
		rm -f "$f.nfs-02"
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

rm -rf --one-file-system /srv/projects /srv/docs

if ! had user-projdata && getent passwd projdata >/dev/null; then
	# The empty mail spool that useradd creates
	for m in /var/spool/mail/projdata /var/mail/projdata; do
		[ -f "$m" ] && [ ! -L "$m" ] && [ ! -s "$m" ] && rm -f "$m"
	done
	userdel projdata </dev/null >/dev/null 2>&1 || {
		echo "cannot remove the user projdata" >&2
		exit 1
	}
fi
if ! had group-projdata && getent group projdata >/dev/null; then
	groupdel projdata </dev/null >/dev/null 2>&1 || {
		echo "cannot remove the group projdata" >&2
		exit 1
	}
fi
exit 0
REMOTE

# Node 1 after the package restore: exports file and nfs-server as
# recorded where nfs-utils was there before the lab
cat > "$tmp/server-post.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre

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
# Client first, so that the mounts go while the server still answers
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if [ "$n" = 2 ]; then
		cat "$tmp/automap.sh" "$tmp/client.sh" > "$tmp/stop.sh"
		cat "$tmp/client-post.sh" > "$tmp/post.sh"
	else
		cat "$tmp/server.sh" > "$tmp/stop.sh"
		cat "$tmp/server-post.sh" > "$tmp/post.sh"
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
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/post.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
