#!/bin/bash
# samba-01 cleanup: puts nodes 1 and 2 back into the state that the
# first setup.sh run recorded. Node 2 goes first: the CIFS mount, its
# fstab entry, /root/team.creds and /mnt/team go while node 1 still
# serves the share. On node 1 the share [team], the Samba account of
# smbuser, the file context rules below /srv/samba, the samba firewall
# services, /srv/samba/team and the lab accounts go. Where the lab
# installed samba, its services stop and its data directories go; then
# the package set of the first start comes back (lib/packages.sh), which
# also removes the group printadmin that samba-common creates. Where
# samba was there before, the recorded smb.conf and the recorded state
# of smb and nmb come back. When a node cannot be restored, its records
# stay for the next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=samba-01
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 2 before the package restore: no mount, no fstab entry, no
# credentials file
cat > "$tmp/client.sh" <<'REMOTE'
pre=/var/tmp/samba-01.pre
mp=/mnt/team

# setup.sh never recorded this node: nothing to undo
[ -d "$pre" ] || exit 0

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

# Node 2 after the package restore
cat > "$tmp/client-post.sh" <<'REMOTE'
rm -rf /var/tmp/samba-01.pre
exit 0
REMOTE

# Node 1 before the package restore: no share, no Samba account, no
# file context rule, firewall as recorded, no lab directory and no lab
# accounts. Where the lab installed samba, its services stop and the
# data they wrote goes.
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/samba-01.pre
snap=/opt/linux-labs/state/samba-01.packages/packages

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

new_pkg() {
	[ -s "$snap" ] && rpm -q "$1" >/dev/null 2>&1 && ! grep -q "^$1\." "$snap"
}

if [ -f /etc/samba/smb.conf ]; then
	awk '/^[[:space:]]*\[/ { s = tolower($0); gsub(/[[:space:]]/, "", s); skip = (s == "[team]") } !skip' \
		/etc/samba/smb.conf > /etc/samba/smb.conf.samba-01 || exit 1
	cat /etc/samba/smb.conf.samba-01 > /etc/samba/smb.conf || exit 1
	rm -f /etc/samba/smb.conf.samba-01
fi
if command -v pdbedit >/dev/null 2>&1 &&
	pdbedit -L </dev/null 2>/dev/null | grep -q '^smbuser:'; then
	pdbedit -x smbuser </dev/null >/dev/null 2>&1
fi

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
		if had "fw-$s"; then
			firewall-cmd --permanent --add-service="$s" </dev/null >/dev/null 2>&1
		else
			firewall-cmd --permanent --remove-service="$s" </dev/null >/dev/null 2>&1
		fi
	done
	firewall-cmd --reload </dev/null >/dev/null 2>&1
fi

if new_pkg samba || new_pkg samba-common; then
	systemctl disable --now smb nmb </dev/null >/dev/null 2>&1
	systemctl stop samba winbind </dev/null >/dev/null 2>&1
	rm -rf /var/lib/samba /var/cache/samba /var/log/samba /run/samba
fi

rm -rf --one-file-system /srv/samba/team
had dir-srv-samba || rmdir /srv/samba 2>/dev/null

if ! had user-smbuser && getent passwd smbuser >/dev/null; then
	# The empty mail spool that useradd creates
	for m in /var/spool/mail/smbuser /var/mail/smbuser; do
		[ -f "$m" ] && [ ! -L "$m" ] && [ ! -s "$m" ] && rm -f "$m"
	done
	userdel smbuser </dev/null >/dev/null 2>&1 || {
		echo "cannot remove the user smbuser" >&2
		exit 1
	}
fi
if ! had group-smbteam && getent group smbteam >/dev/null; then
	groupdel smbteam </dev/null >/dev/null 2>&1 || {
		echo "cannot remove the group smbteam" >&2
		exit 1
	}
fi
exit 0
REMOTE

# Node 1 after the package restore: smb.conf, smb and nmb as recorded
# where samba was there before the lab; no leftovers where it was not
cat > "$tmp/server-post.sh" <<'REMOTE'
pre=/var/tmp/samba-01.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if rpm -q samba-common >/dev/null 2>&1; then
	if [ -f "$pre/smb.conf" ]; then
		cat "$pre/smb.conf" > /etc/samba/smb.conf
	fi
else
	rm -rf /etc/samba /var/lib/samba /var/cache/samba /var/log/samba /run/samba
fi
for s in smb nmb; do
	systemctl cat "$s" </dev/null >/dev/null 2>&1 || continue
	if had "$s-enabled"; then
		systemctl enable "$s" </dev/null >/dev/null 2>&1
	else
		systemctl disable "$s" </dev/null >/dev/null 2>&1
	fi
	if had "$s-active"; then
		systemctl restart "$s" </dev/null >/dev/null 2>&1
	else
		systemctl stop "$s" </dev/null >/dev/null 2>&1
	fi
done
rm -rf "$pre"
exit 0
REMOTE

rc=0
# Client first, so that the mount goes while the server still answers
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if [ "$n" = 2 ]; then
		cat "$tmp/client.sh" > "$tmp/stop.sh"
		cat "$tmp/client-post.sh" > "$tmp/post.sh"
	else
		cat "$tmp/server.sh" > "$tmp/stop.sh"
		cat "$tmp/server-post.sh" > "$tmp/post.sh"
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" > "$tmp/out" 2>&1; then
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
