#!/bin/bash
# nfs-02 setup: puts nodes 1 and 2 into the starting state. Node 1 has
# the user and group projdata (UID and GID 3001), the directory
# /srv/projects owned by them and the directory /srv/docs owned by root,
# each with one file. Neither directory is exported, the NFS server is
# stopped and disabled and the firewall has no NFS rule. Node 2 has no
# autofs map for /shares, autofs is stopped and disabled and nothing is
# mounted below /shares. Prints nothing on success.
#
# The first run records each node's package set (lib/packages.sh), so
# that cleanup.sh removes nfs-utils, rpcbind and autofs again where the
# lab installed them. It also records in /var/tmp/nfs-02.pre on each
# node the state cleanup.sh puts back: on node 1 nfs-server, the NFS
# firewall services, a copy of /etc/exports and whether projdata
# existed; on node 2 the state of autofs.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=nfs-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	echo "$LAB needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Shared with cleanup.sh: remove every autofs master entry for /shares
# from /etc/auto.master and /etc/auto.master.d, and the map files those
# entries name when no package owns them.
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

# Node 2, the client: record the autofs state once, then no /shares map,
# autofs stopped and disabled, nothing mounted below /shares. Runs as
# root through "bash -s", so every command that could read stdin gets
# /dev/null instead of the script.
cat > "$tmp/client.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		rpm -q autofs >/dev/null 2>&1 && echo autofs-installed
		systemctl is-enabled --quiet autofs 2>/dev/null && echo autofs-enabled
		systemctl is-active --quiet autofs 2>/dev/null && echo autofs-active
	} > "$pre.tmp/flags"
	mv "$pre.tmp" "$pre" || exit 1
fi

remove_shares_maps || exit 1
if systemctl cat autofs </dev/null >/dev/null 2>&1; then
	systemctl disable --now autofs </dev/null >/dev/null 2>&1
fi
unmount_shares || exit 1
rmdir /shares 2>/dev/null
exit 0
REMOTE

# Node 1, the server: record the state from before the lab once, then
# remove the exports, stop the NFS server, close the firewall and create
# the user, the group and the directories with their files.
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/nfs-02.pre
id=3001

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		systemctl is-enabled --quiet nfs-server 2>/dev/null && echo nfs-server-enabled
		systemctl is-active --quiet nfs-server 2>/dev/null && echo nfs-server-active
		for s in nfs mountd rpc-bind; do
			firewall-cmd --permanent --query-service="$s" </dev/null >/dev/null 2>&1 && echo "fw-$s"
		done
		getent passwd projdata >/dev/null && echo user-projdata
		getent group projdata >/dev/null && echo group-projdata
	} > "$pre.tmp/flags"
	if [ -f /etc/exports ]; then
		cp -a /etc/exports "$pre.tmp/exports" || exit 1
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

# No export of the lab directories in /etc/exports or /etc/exports.d
for f in /etc/exports /etc/exports.d/*.exports; do
	[ -f "$f" ] || continue
	if awk '$1 ~ /^\/srv\/(projects|docs)\/?$/ { f = 1 } END { exit !f }' "$f"; then
		awk '$1 !~ /^\/srv\/(projects|docs)\/?$/' "$f" > "$f.nfs-02" || exit 1
		cat "$f.nfs-02" > "$f" || exit 1
		rm -f "$f.nfs-02"
	fi
done
if systemctl cat nfs-server </dev/null >/dev/null 2>&1; then
	command -v exportfs >/dev/null 2>&1 && exportfs -ua </dev/null >/dev/null 2>&1
	systemctl disable --now nfs-server </dev/null >/dev/null 2>&1
fi

if systemctl is-active --quiet firewalld; then
	for s in nfs mountd rpc-bind; do
		firewall-cmd --permanent --remove-service="$s" </dev/null >/dev/null 2>&1
	done
	firewall-cmd --reload </dev/null >/dev/null 2>&1 || {
		echo "firewall-cmd --reload failed" >&2
		exit 1
	}
fi

# The group and user projdata with ID 3001; another account with that
# ID stops the setup
g=$(getent group "$id" | cut -d: -f1)
if [ -n "$g" ] && [ "$g" != projdata ]; then
	echo "GID $id belongs to the group $g, the lab needs it for projdata" >&2
	exit 1
fi
u=$(getent passwd "$id" | cut -d: -f1)
if [ -n "$u" ] && [ "$u" != projdata ]; then
	echo "UID $id belongs to the user $u, the lab needs it for projdata" >&2
	exit 1
fi
if getent group projdata >/dev/null && [ "$(getent group projdata | cut -d: -f3)" != "$id" ]; then
	echo "The group projdata exists with a GID other than $id" >&2
	exit 1
fi
if getent passwd projdata >/dev/null && [ "$(getent passwd projdata | cut -d: -f3)" != "$id" ]; then
	echo "The user projdata exists with a UID other than $id" >&2
	exit 1
fi
if ! getent group projdata >/dev/null; then
	groupadd -g "$id" projdata || exit 1
fi
if ! getent passwd projdata >/dev/null; then
	useradd -u "$id" -g projdata -M -d /srv/projects -s /sbin/nologin \
		-c "nfs-02 lab data owner" projdata || exit 1
fi

rm -rf --one-file-system /srv/projects /srv/docs
mkdir -p /srv/projects /srv/docs || exit 1
echo "Project files are shared from node 1." > /srv/projects/README.txt || exit 1
echo "Documentation is shared read-only from node 1." > /srv/docs/manual.txt || exit 1
chown -R projdata:projdata /srv/projects
chmod 0770 /srv/projects
chmod 0660 /srv/projects/README.txt
chown -R root:root /srv/docs
chmod 0755 /srv/docs
chmod 0644 /srv/docs/manual.txt
restorecon -R /srv/projects /srv/docs >/dev/null 2>&1
exit 0
REMOTE

# Client first, so that no mount hangs on a server that goes away
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if [ "$n" = 2 ]; then
		cat "$tmp/automap.sh" "$tmp/client.sh" > "$tmp/run.sh"
	else
		cat "$tmp/server.sh" > "$tmp/run.sh"
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/run.sh" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

# The grader checks that the lab was started
mkdir -p "$STATE_DIR"
echo "nodes=$(get_node_ip 1) $(get_node_ip 2)" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
