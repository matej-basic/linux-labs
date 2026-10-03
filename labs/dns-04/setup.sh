#!/bin/bash
# dns-04 setup: records on both nodes what the lab may change, so that
# cleanup.sh puts it back, then makes node 1 the primary of the zone
# lab.example. Each node keeps in /var/tmp/dns-04.pre the ports and
# services of every firewalld zone (runtime and permanent), whether
# bind was installed, the unit state of named, a copy of
# /etc/named.conf and the list of files under /var/named. The package
# set of both nodes goes into the snapshot of lib/packages.sh.
# Node 1 then gets bind and bind-utils, the zone file
# /var/named/lab.example.zone and a zone statement for it in
# /etc/named.conf, with named stopped and disabled. Node 2 is left as
# it was: the student installs and configures BIND there.
# A restart first runs cleanup.sh, so every start begins from the
# state before the lab.
# Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=dns-04
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

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $ip over SSH as $SSH_USER" >&2
		exit 1
	fi
done

# Undo an earlier start and its solution first. cleanup.sh does nothing
# on a node without records.
if ! bash "$(dirname "$0")/cleanup.sh"; then
	echo "Undoing an earlier start of $LAB failed." >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Both nodes: the records. Runs as root through "bash -s".
cat > "$tmp/record.sh" <<'REMOTE'
pre=/var/tmp/dns-04.pre

if ! firewall-cmd --state >/dev/null 2>&1; then
	echo "firewalld is not running" >&2
	exit 1
fi

fw_dump() {
	firewall-cmd "$@" --list-all-zones | awk '
		/^[^ \t]/ { zone = $1 }
		/^[ \t]+services:/ { for (i = 2; i <= NF; i++) print zone, "service", $i }
		/^[ \t]+ports:/ { for (i = 2; i <= NF; i++) print zone, "port", $i }
	' | LC_ALL=C sort
}

[ -d "$pre" ] && exit 0
rm -rf "$pre.tmp"
mkdir -m 0700 "$pre.tmp" || exit 1
fw_dump > "$pre.tmp/fw.runtime" || exit 1
fw_dump --permanent > "$pre.tmp/fw.permanent" || exit 1
if [ -f /etc/named.conf ]; then
	cp -a /etc/named.conf "$pre.tmp/named.conf" || exit 1
fi
if [ -d /var/named ]; then
	find /var/named -xdev ! -type d | LC_ALL=C sort > "$pre.tmp/files"
fi
{
	rpm -q bind >/dev/null 2>&1 && echo bind-installed
	[ -e /var/named ] && echo var-named-existed
	systemctl is-enabled --quiet named 2>/dev/null && echo named-enabled
	systemctl is-active --quiet named 2>/dev/null && echo named-active
} > "$pre.tmp/flags"
mv "$pre.tmp" "$pre" || exit 1
exit 0
REMOTE

# Node 1: BIND with the primary zone lab.example. $1 is the node 1
# address.
cat > "$tmp/node1.sh" <<'REMOTE'
n1=$1
zone=/var/named/lab.example.zone

if ! rpm -q bind bind-utils >/dev/null 2>&1; then
	if ! dnf -y -q install bind bind-utils </dev/null >/dev/null 2>"/var/tmp/dns-04.dnf"; then
		echo "Installing bind and bind-utils failed:" >&2
		cat /var/tmp/dns-04.dnf >&2
		rm -f /var/tmp/dns-04.dnf
		exit 1
	fi
	rm -f /var/tmp/dns-04.dnf
fi
systemctl disable --now named </dev/null >/dev/null 2>&1
systemctl reset-failed named </dev/null >/dev/null 2>&1

cat > "$zone" <<ZONE || exit 1
\$TTL 3600
@       IN SOA  ns1.lab.example. hostmaster.lab.example. (
                2026100301 ; serial
                3600       ; refresh
                600        ; retry
                86400      ; expire
                300 )      ; negative caching TTL
        IN NS   ns1.lab.example.
        IN MX   10 mail.lab.example.
ns1     IN A    $n1
www     IN A    192.0.2.10
mail    IN A    192.0.2.20
ftp     IN CNAME www
ZONE
chown root:named "$zone" && chmod 0640 "$zone" || exit 1
restorecon "$zone" >/dev/null 2>&1

if ! grep -q '^zone "lab.example"' /etc/named.conf; then
	cat >> /etc/named.conf <<'CONF' || exit 1

zone "lab.example" IN {
	type master;
	file "lab.example.zone";
};
CONF
fi

if ! named-checkconf /etc/named.conf >&2; then
	echo "/etc/named.conf on node 1 does not pass named-checkconf" >&2
	exit 1
fi
if ! named-checkzone lab.example "$zone" >/dev/null; then
	echo "$zone does not pass named-checkzone" >&2
	exit 1
fi
exit 0
REMOTE

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/record.sh" > /dev/null 2> "$tmp/err"; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		exit 1
	fi
done

if ! run_on_node "$N1" "sudo -n bash -s -- $N1" < "$tmp/node1.sh" > /dev/null 2> "$tmp/err"; then
	echo "Preparing the primary zone on node 1 ($N1) failed:" >&2
	grep -v "^Warning: Permanently added" "$tmp/err" >&2
	exit 1
fi

mkdir -p "$STATE_DIR"
printf 'node1=%s\nnode2=%s\n' "$N1" "$N2" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
