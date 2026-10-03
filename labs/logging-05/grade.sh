#!/bin/bash
# logging-05 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

LAB=logging-05
STATE_FILE=/opt/linux-labs/state/$LAB

grade_begin logging-05
grade_require_state logging-05 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# on <ip> <command>: run a command as root on a node
on() {
	run_on_node "$1" "sudo -n bash -c '$2'" </dev/null 2>/dev/null
}

rsyslog_up() {
	on "$1" "systemctl is-active --quiet rsyslog && systemctl is-enabled --quiet rsyslog"
}

listens_514() {
	[ -n "$(on "$N1" "ss -Hltn sport = :514")" ]
}

# fw_allows [--permanent]: the zone of the interface with the node 1
# address (or the default zone) has port 514/tcp, or a service with it
fw_allows() {
	run_on_node "$N1" "sudo -n bash -s -- $N1 $*" 2>/dev/null <<'REMOTE'
addr=$1
shift
iface=$(ip -o -4 addr show | awk -v a="$addr" '{ split($4, x, "/"); if (x[1] == a) print $2 }')
zone=
[ -n "$iface" ] && zone=$(firewall-cmd "$@" --get-zone-of-interface="$iface" 2>/dev/null)
[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone)
firewall-cmd "$@" --zone="$zone" --query-port=514/tcp >/dev/null 2>&1 && exit 0
for s in $(firewall-cmd "$@" --zone="$zone" --list-services); do
	firewall-cmd "$@" --info-service="$s" 2>/dev/null |
		grep -E '^[[:space:]]+ports:' |
		grep -Eq '(:|[[:space:]])514/tcp([[:space:]]|$)' && exit 0
done
exit 1
REMOTE
}

# The rsyslog configuration of node 2 without comments, once as lines
# and once joined into one line, and the action(...) blocks in it
cfg=$(on "$N2" "cat /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null" | sed 's/#.*$//')
joined=$(printf '%s\n' "$cfg" | tr '\n\t' '  ')
blocks=$(printf '%s\n' "$joined" | grep -oiE 'action[[:space:]]*\([^)]*\)')
ipre=${N1//./\\.}

# param <block> <name> <value regex>: the block sets the parameter
param() {
	printf '%s\n' "$1" | grep -qiE "[(,[:space:]]$2[[:space:]]*=[[:space:]]*\"$3\""
}

# Forwarding actions to node 1 over TCP, port 514 if a port is set
fwd_blocks=()
while IFS= read -r b; do
	[ -n "$b" ] || continue
	param "$b" type omfwd || continue
	param "$b" target "$ipre" || continue
	param "$b" protocol tcp || continue
	if param "$b" port '[^"]*' && ! param "$b" port 514; then
		continue
	fi
	fwd_blocks+=("$b")
done <<< "$blocks"

# The legacy form: @@<address>[:514] and $Action... directives
legacy=1
printf '%s\n' "$cfg" | grep -Eq "@@(\([^)]*\))?$ipre(:514)?([[:space:];]|$)" && legacy=0

forwards_tcp() {
	[ "${#fwd_blocks[@]}" -gt 0 ] || [ "$legacy" -eq 0 ]
}

has_disk_queue() {
	local b
	for b in "${fwd_blocks[@]}"; do
		param "$b" 'queue\.type' '(linkedlist|disk)' &&
			param "$b" 'queue\.filename' '[^"]+' && return 0
	done
	# shellcheck disable=SC2016 # $ActionQueue... are literal directives
	[ "$legacy" -eq 0 ] &&
		printf '%s\n' "$cfg" | grep -Eiq '^[[:space:]]*\$ActionQueueType[[:space:]]+(LinkedList|Disk)' &&
		printf '%s\n' "$cfg" | grep -Eiq '^[[:space:]]*\$ActionQueueFileName[[:space:]]+[^[:space:]]'
}

retries_forever() {
	local b
	for b in "${fwd_blocks[@]}"; do
		param "$b" 'action\.resumeretrycount' '-1' && return 0
	done
	# shellcheck disable=SC2016 # $ActionResumeRetryCount is a literal directive
	[ "$legacy" -eq 0 ] &&
		printf '%s\n' "$cfg" | grep -Eiq '^[[:space:]]*\$ActionResumeRetryCount[[:space:]]+-1([[:space:]]|$)'
}

# A message sent on node 2 shows up on node 1 in the file of node 2
h2=$(run_on_node "$N2" "hostname -s" </dev/null 2>/dev/null)
h2=${h2:-node2}
REMOTE_FILE=/var/log/remote/$h2/messages
tok2="logging-05-remote-$(date +%s)-$RANDOM"
tok1="logging-05-local-$(date +%s)-$RANDOM"

message_arrives() {
	on "$N2" "logger -p user.info -t labcheck $tok2" || return 1
	on "$N1" "for i in \$(seq 1 20); do grep -qF $tok2 $REMOTE_FILE 2>/dev/null && exit 0; sleep 1; done; exit 1"
}

# A message of node 1 itself reaches /var/log/messages there, but not
# /var/log/remote
local_stays_local() {
	on "$N1" "logger -p user.info -t labcheck $tok1" || return 1
	on "$N1" "test -d /var/log/remote && for i in \$(seq 1 20); do grep -qF $tok1 /var/log/messages 2>/dev/null && break; sleep 1; done && grep -qF $tok1 /var/log/messages && sleep 2 && ! grep -rqF $tok1 /var/log/remote"
}

criterion "rsyslog is enabled and running on node 1" rsyslog_up "$N1"
criterion "rsyslog is enabled and running on node 2" rsyslog_up "$N2"
criterion "rsyslog on node 1 listens on port 514/tcp" listens_514
criterion "The node 1 runtime firewall allows 514/tcp" fw_allows
criterion "The node 1 permanent firewall allows 514/tcp" fw_allows --permanent
criterion "Node 2 forwards to $N1 port 514 over TCP" forwards_tcp
criterion "The forwarding action has a disk-assisted queue" has_disk_queue
criterion "The forwarding action retries without limit" retries_forever
criterion "A node 2 message arrives in $REMOTE_FILE" message_arrives
criterion "Node 1 logs its own messages locally only" local_stays_local
grade_end
