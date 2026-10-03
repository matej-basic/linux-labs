#!/bin/bash
# samba-01 setup: puts nodes 1 and 2 into the starting state. Node 1 has
# the group smbteam (GID 3410), the user smbuser (UID 3411, member of
# smbteam, no Samba password) and the directory /srv/samba/team owned by
# root and smbteam, mode 2770, with the default SELinux type. There is
# no share [team] in smb.conf, no SELinux file context rule below
# /srv/samba, smb is stopped and disabled and the firewall has no samba
# rule. Node 2 has no mount at /mnt/team, no fstab entry for it and no
# /root/team.creds. Prints nothing on success.
#
# The first run records each node's package set (lib/packages.sh), so
# that cleanup.sh removes samba, cifs-utils and their dependencies again
# where the lab installed them. On node 1 it also records in
# /var/tmp/samba-01.pre the state cleanup.sh puts back: smb and nmb, the
# samba firewall services, a copy of /etc/samba/smb.conf and whether
# the lab accounts existed.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=samba-01
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

# Node 2, the client: no mount, no fstab entry and no credentials file.
# Runs as root through "bash -s", so every command that could read stdin
# gets /dev/null instead of the script.
cat > "$tmp/client.sh" <<'REMOTE'
pre=/var/tmp/samba-01.pre
mp=/mnt/team

if [ ! -d "$pre" ]; then
	mkdir -m 0700 "$pre" || exit 1
fi

if mountpoint -q "$mp" 2>/dev/null; then
	umount "$mp" </dev/null >/dev/null 2>&1 ||
		umount -f -l "$mp" </dev/null >/dev/null 2>&1
fi
if mountpoint -q "$mp" 2>/dev/null; then
	echo "cannot unmount $mp" >&2
	exit 1
fi
if awk -v m="$mp" '$1 !~ /^#/ && ($2 == m || $2 == m "/") { f = 1 } END { exit !f }' /etc/fstab; then
	awk -v m="$mp" '$1 ~ /^#/ || ($2 != m && $2 != m "/")' /etc/fstab > /etc/fstab.samba-01 || exit 1
	cat /etc/fstab.samba-01 > /etc/fstab || exit 1
	rm -f /etc/fstab.samba-01
	systemctl daemon-reload </dev/null >/dev/null 2>&1
fi
rm -f /root/team.creds
rmdir "$mp" 2>/dev/null
exit 0
REMOTE

# Node 1, the server: record the state from before the lab once, then
# remove the share, the file context rules, the Samba account and the
# firewall rule, stop smb and create the accounts and the directory.
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/samba-01.pre
gid=3410
uid=3411

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		for s in smb nmb; do
			systemctl is-enabled --quiet "$s" 2>/dev/null && echo "$s-enabled"
			systemctl is-active --quiet "$s" 2>/dev/null && echo "$s-active"
		done
		for s in samba samba-client; do
			firewall-cmd --permanent --query-service="$s" </dev/null >/dev/null 2>&1 && echo "fw-$s"
		done
		getent passwd smbuser >/dev/null && echo user-smbuser
		getent group smbteam >/dev/null && echo group-smbteam
		[ -d /srv/samba ] && echo dir-srv-samba
	} > "$pre.tmp/flags"
	if [ -f /etc/samba/smb.conf ]; then
		cp -a /etc/samba/smb.conf "$pre.tmp/smb.conf" || exit 1
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

# No share [team] in smb.conf
if [ -f /etc/samba/smb.conf ]; then
	awk '/^[[:space:]]*\[/ { s = tolower($0); gsub(/[[:space:]]/, "", s); skip = (s == "[team]") } !skip' \
		/etc/samba/smb.conf > /etc/samba/smb.conf.samba-01 || exit 1
	cat /etc/samba/smb.conf.samba-01 > /etc/samba/smb.conf || exit 1
	rm -f /etc/samba/smb.conf.samba-01
fi
if systemctl cat smb </dev/null >/dev/null 2>&1; then
	systemctl disable --now smb </dev/null >/dev/null 2>&1
fi
if command -v pdbedit >/dev/null 2>&1 &&
	pdbedit -L </dev/null 2>/dev/null | grep -q '^smbuser:'; then
	pdbedit -x smbuser </dev/null >/dev/null 2>&1
fi

# No local file context rule below /srv/samba
if command -v semanage >/dev/null 2>&1; then
	semanage fcontext -l -C </dev/null 2>/dev/null |
		awk '$1 ~ /^\/srv\/samba/ { print $1 }' | sort -u |
		while IFS= read -r re; do
			for t in a f d c b s l p; do
				semanage fcontext -d -f "$t" -- "$re" </dev/null >/dev/null 2>&1
			done
		done
fi

if systemctl is-active --quiet firewalld; then
	for s in samba samba-client; do
		firewall-cmd --permanent --remove-service="$s" </dev/null >/dev/null 2>&1
	done
	firewall-cmd --reload </dev/null >/dev/null 2>&1 || {
		echo "firewall-cmd --reload failed" >&2
		exit 1
	}
fi

# The group smbteam and the user smbuser with fixed IDs; another account
# with one of those IDs stops the setup
g=$(getent group "$gid" | cut -d: -f1)
if [ -n "$g" ] && [ "$g" != smbteam ]; then
	echo "GID $gid belongs to the group $g, the lab needs it for smbteam" >&2
	exit 1
fi
u=$(getent passwd "$uid" | cut -d: -f1)
if [ -n "$u" ] && [ "$u" != smbuser ]; then
	echo "UID $uid belongs to the user $u, the lab needs it for smbuser" >&2
	exit 1
fi
if getent group smbteam >/dev/null && [ "$(getent group smbteam | cut -d: -f3)" != "$gid" ]; then
	echo "The group smbteam exists with a GID other than $gid" >&2
	exit 1
fi
if getent passwd smbuser >/dev/null && [ "$(getent passwd smbuser | cut -d: -f3)" != "$uid" ]; then
	echo "The user smbuser exists with a UID other than $uid" >&2
	exit 1
fi
if ! getent group smbteam >/dev/null; then
	groupadd -g "$gid" smbteam || exit 1
fi
if ! getent passwd smbuser >/dev/null; then
	useradd -u "$uid" -U -G smbteam -M -s /sbin/nologin \
		-c "samba-01 lab user" smbuser || exit 1
else
	usermod -a -G smbteam smbuser || exit 1
fi

rm -rf --one-file-system /srv/samba/team
mkdir -p /srv/samba/team || exit 1
chown root:smbteam /srv/samba/team
chmod 2770 /srv/samba/team
restorecon -R /srv/samba >/dev/null 2>&1
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
		cat "$tmp/client.sh" > "$tmp/run.sh"
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
