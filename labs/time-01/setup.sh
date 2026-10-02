#!/bin/bash
# time-01 setup: puts nodes 1 and 2 into the starting state. Both nodes
# have their chrony configuration as it was before the lab. On node 1
# chronyd is stopped and disabled and the firewall has no ntp service.
# On node 2 chronyd runs as before the lab and the time zone is UTC.
# Prints nothing on success.
#
# The first run records the package set of each node (lib/packages.sh)
# and, in /var/tmp/time-01.pre on each node, a copy of the chrony
# configuration files, the boot and running state of chronyd, the ntp
# firewall service and the time zone, so that cleanup.sh puts all of it
# back. A later run restores the recorded configuration files first.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=time-01
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

# Runs as root on a node through "bash -s" after a first line that sets
# role=server or role=client. Every command that could read stdin gets
# /dev/null instead of the script.
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/time-01.pre
paths="/etc/chrony.conf /etc/chrony.keys /etc/sysconfig/chronyd /etc/chrony.d"

if ! rpm -q chrony >/dev/null 2>&1; then
	dnf -y install chrony </dev/null >/dev/null 2>&1 || {
		echo "chrony is not installed and cannot be installed" >&2
		exit 1
	}
fi
if [ "$role" = server ] && ! systemctl is-active --quiet firewalld; then
	echo "firewalld is not running on node 1" >&2
	exit 1
fi

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" "$pre.tmp/files" || exit 1
	{
		systemctl is-enabled --quiet chronyd 2>/dev/null && echo chronyd-enabled
		systemctl is-active --quiet chronyd 2>/dev/null && echo chronyd-active
		firewall-cmd --permanent --query-service=ntp </dev/null >/dev/null 2>&1 && echo fw-ntp
	} > "$pre.tmp/flags"
	tz=$(timedatectl show -p Timezone --value </dev/null 2>/dev/null)
	[ -n "$tz" ] || tz=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
	echo "$tz" > "$pre.tmp/timezone"
	for p in $paths; do
		if [ -e "$p" ]; then
			cp -a "$p" "$pre.tmp/files/${p##*/}" || exit 1
		fi
	done
	mv "$pre.tmp" "$pre" || exit 1
fi

# The recorded configuration files, also after a partial solution
for p in $paths; do
	saved="$pre/files/${p##*/}"
	if [ -e "$saved" ]; then
		if [ -f "$saved" ] && [ -f "$p" ] && cmp -s "$saved" "$p"; then
			continue
		fi
		rm -rf "$p"
		cp -a "$saved" "$p" || exit 1
	else
		rm -rf "$p"
	fi
done
restorecon -R /etc/chrony.conf /etc/chrony.keys /etc/sysconfig/chronyd \
	>/dev/null 2>&1

if [ "$role" = server ]; then
	systemctl disable --now chronyd </dev/null >/dev/null 2>&1
	firewall-cmd --permanent --remove-service=ntp </dev/null >/dev/null 2>&1
	firewall-cmd --reload </dev/null >/dev/null 2>&1 || {
		echo "firewall-cmd --reload failed" >&2
		exit 1
	}
else
	if grep -qx chronyd-enabled "$pre/flags"; then
		systemctl enable chronyd </dev/null >/dev/null 2>&1
	else
		systemctl disable chronyd </dev/null >/dev/null 2>&1
	fi
	if grep -qx chronyd-active "$pre/flags"; then
		systemctl restart chronyd </dev/null >/dev/null 2>&1 || {
			echo "chronyd does not start on node 2" >&2
			exit 1
		}
	else
		systemctl stop chronyd </dev/null >/dev/null 2>&1
	fi
	timedatectl set-timezone UTC </dev/null >/dev/null 2>&1 || {
		echo "cannot set the time zone UTC on node 2" >&2
		exit 1
	}
fi
exit 0
REMOTE

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if [ "$n" = 1 ]; then role=server; else role=client; fi
	if ! { echo "role=$role"; cat "$tmp/node.sh"; } |
		run_on_node "$ip" "sudo -n bash -s" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		exit 1
	fi
done

# The grader checks that the lab was started
mkdir -p "$STATE_DIR"
echo "nodes=$(get_node_ip 1) $(get_node_ip 2)" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
