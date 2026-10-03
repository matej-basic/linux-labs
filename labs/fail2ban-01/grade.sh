#!/bin/bash
# fail2ban-01 grader
#
# Values are read from the running server through fail2ban-client, after
# a reload, so they are the values of the configuration files. The ban
# test bans and unbans the documentation address 192.0.2.77 (TEST-NET-1),
# which no real client uses.
source /opt/linux-labs/lib/grading.sh

LAB=fail2ban-01
STATE_FILE=/opt/linux-labs/state/$LAB
TEST_IP=192.0.2.77

grade_begin fail2ban-01
grade_require_state fail2ban-01 "$STATE_FILE"
net=$(sed -n 's/^net=//p' "$STATE_FILE")

f2b() {
	timeout 30 fail2ban-client "$@" 2>/dev/null
}

# jail.conf belongs to the package and is not modified
jail_conf_unchanged() {
	local out
	[ -f /etc/fail2ban/jail.conf ] || return 1
	rpm -qf /etc/fail2ban/jail.conf >/dev/null 2>&1 || return 1
	out=$(rpm -Vf /etc/fail2ban/jail.conf 2>/dev/null) || {
		# rpm -V exits 1 when any file of the package differs
		[ -n "$out" ] || return 1
	}
	! printf '%s\n' "$out" | grep -q ' /etc/fail2ban/jail.conf$'
}

value_is() {
	[ "$(f2b get sshd "$1" | tr -d '[:space:]')" = "$2" ]
}

# The ignoreip entries, one per line, without the tree drawing
ignore_entries() {
	f2b get sshd ignoreip | sed -n 's/^[|`]- *//p'
}

ip2int() {
	local IFS=. a b c d
	read -r a b c d <<< "$1"
	echo $(((a << 24) + (b << 16) + (c << 8) + d))
}

# covers <ipv4 network/prefix>: an ignoreip entry contains the whole network
covers() {
	local want=$1 waddr wlen e addr len w x
	waddr=${want%/*}
	wlen=${want#*/}
	w=$(ip2int "$waddr")
	while read -r e; do
		[[ $e =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]] || continue
		addr=${e%/*}
		len=32
		[ "$addr" != "$e" ] && len=${e#*/}
		[ "$len" -le "$wlen" ] || continue
		x=$(ip2int "$addr")
		if [ "$len" -eq 0 ] || [ $((x >> (32 - len))) -eq $((w >> (32 - len))) ]; then
			return 0
		fi
	done < <(ignore_entries)
	return 1
}

loopback_ignored() {
	covers 127.0.0.0/8 || return 1
	ignore_entries | grep -Eqx '::1(/128)?'
}

banned_in_jail() {
	f2b get sshd banned | tr -d "[]'," | tr ' ' '\n' | grep -qx "$TEST_IP"
}

# The address is in a firewalld rich rule, in a firewalld ipset, or in an
# ipset that a firewalld direct rule matches
in_firewalld() {
	local z s
	for z in $(firewall-cmd --get-zones 2>/dev/null); do
		firewall-cmd --zone="$z" --list-rich-rules 2>/dev/null |
			grep -q "address=\"$TEST_IP\"" && return 0
	done
	for s in $(firewall-cmd --get-ipsets 2>/dev/null); do
		firewall-cmd --ipset="$s" --get-entries 2>/dev/null |
			grep -qx "$TEST_IP" && return 0
	done
	command -v ipset >/dev/null 2>&1 || return 1
	for s in $(firewall-cmd --direct --get-all-rules 2>/dev/null |
		grep -o -- '--match-set [^ ]*' | awk '{ print $2 }' | sort -u); do
		ipset test "$s" "$TEST_IP" >/dev/null 2>&1 && return 0
	done
	return 1
}

# wait_for <0|1> <cmd>: wait up to 10 seconds until the command succeeds
# (1) or fails (0); the ban actions run in their own thread
wait_for() {
	local want=$1 i
	shift
	for i in $(seq 1 20); do
		if "$@"; then
			[ "$want" = 1 ] && return 0
		else
			[ "$want" = 0 ] && return 0
		fi
		[ "$i" -lt 20 ] && sleep 0.5
	done
	return 1
}

reload_ok=1
jail_ok=1
ban_listed=1
ban_fw=1
unban_fw=1
if rpm -q fail2ban-server >/dev/null 2>&1 && systemctl is-active --quiet fail2ban; then
	f2b reload >/dev/null && reload_ok=0
	f2b status sshd >/dev/null && jail_ok=0
fi
if [ "$jail_ok" = 0 ]; then
	f2b set sshd banip "$TEST_IP" >/dev/null
	wait_for 1 banned_in_jail && ban_listed=0
	wait_for 1 in_firewalld && ban_fw=0
	f2b set sshd unbanip "$TEST_IP" >/dev/null
	if [ "$ban_fw" = 0 ] && wait_for 0 in_firewalld && ! banned_in_jail; then
		unban_fw=0
	fi
fi

criterion "Package fail2ban is installed" rpm -q fail2ban
criterion "Service fail2ban is enabled" systemctl is-enabled --quiet fail2ban
criterion "Service fail2ban is active" systemctl is-active --quiet fail2ban
criterion "File /etc/fail2ban/jail.conf is unchanged" jail_conf_unchanged
criterion_result "The fail2ban configuration reloads without errors" "$reload_ok"
criterion_result "Jail sshd is running" "$jail_ok"
criterion "Jail sshd has maxretry 4" value_is maxretry 4
criterion "Jail sshd has findtime 15 minutes" value_is findtime 900
criterion "Jail sshd has bantime 1 hour" value_is bantime 3600
criterion "Jail sshd ignores 127.0.0.1/8 and ::1" loopback_ignored
criterion "Jail sshd ignores the network $net" covers "$net"
criterion_result "A test ban of $TEST_IP is listed in jail sshd" "$ban_listed"
criterion_result "The test ban of $TEST_IP is a firewalld rule" "$ban_fw"
criterion_result "Unbanning $TEST_IP removes it from firewalld" "$unban_fw"
grade_end
