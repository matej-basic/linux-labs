#!/bin/bash
# fail2ban-02 grader
#
# Values are read from the running server through fail2ban-client, after
# a reload, so they are the values of the configuration files. The
# filter is tested with fail2ban-regex against the copies of the log
# that setup.sh kept. The ban test appends four failed logins of the
# documentation address 192.0.2.88 (TEST-NET-1) to the live log, waits
# for the ban, unbans the address and removes the lines again. The jail
# is stopped while the lines are removed and started by a reload: a
# running jail would read the shortened log from the start and treat
# its old lines as new.
source /opt/linux-labs/lib/grading.sh

LAB=fail2ban-02
STATE_FILE=/opt/linux-labs/state/$LAB
DATA_DIR=/opt/linux-labs/state/$LAB.d
LOG=/var/log/labapp/auth.log
TEST_IP=192.0.2.88

grade_begin fail2ban-02
grade_require_state fail2ban-02 "$STATE_FILE"
net=$(sed -n 's/^net=//p' "$STATE_FILE")
fails=$(sed -n 's/^fails=//p' "$STATE_FILE")

f2b() {
	timeout 30 fail2ban-client "$@" 2>/dev/null
}

value_is() {
	[ "$(f2b get labapp "$1" | tr -d '[:space:]')" = "$2" ]
}

# regex_matches <log> <count>: the filter labapp matches exactly <count>
# lines of <log>
regex_matches() {
	local out m
	[ -r "$1" ] || return 1
	out=$(cd / && timeout 60 fail2ban-regex "$1" labapp 2>/dev/null) || return 1
	m=$(printf '%s\n' "$out" |
		sed -n 's/^Lines: [0-9]* lines, [0-9]* ignored, \([0-9]*\) matched.*/\1/p')
	[ -n "$m" ] && [ "$m" = "$2" ]
}

# The entries of a fail2ban-client list, one per line, without the
# header line and the tree drawing
list_entries() {
	sed -e '1d' -e 's/^[|` -]*//' | sed '/^$/d'
}

# The section [labapp] is in a .local file in jail.d
jail_in_jail_d() {
	grep -qsE '^[[:space:]]*\[labapp\][[:space:]]*$' /etc/fail2ban/jail.d/*.local
}

logpath_is_log() {
	f2b get labapp logpath | list_entries | grep -qx "$LOG"
}

# Every action of the jail that has a port bans 8443/tcp, and one has
actions_port() {
	local a p found=1
	while read -r a; do
		p=$(f2b get labapp action "$a" port | tr -d '[:space:]')
		[ -n "$p" ] || continue
		[ "$p" = 8443 ] || return 1
		[ "$(f2b get labapp action "$a" protocol | tr -d '[:space:]')" = tcp ] || return 1
		found=0
	done < <(f2b get labapp actions | list_entries)
	return "$found"
}

ignore_entries() {
	f2b get labapp ignoreip | list_entries
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
	f2b get labapp banned | tr -d "[]'," | tr ' ' '\n' | grep -qx "$TEST_IP"
}

jail_running() {
	f2b status labapp >/dev/null
}

reload_ok=1
jail_ok=1
ban_ok=1
if rpm -q fail2ban-server >/dev/null 2>&1 && systemctl is-active --quiet fail2ban; then
	f2b reload >/dev/null && reload_ok=0
	jail_running && jail_ok=0
fi
if [ "$jail_ok" = 0 ] && [ -f "$LOG" ]; then
	f2b set labapp unbanip "$TEST_IP" >/dev/null
	size=$(stat -c %s "$LOG")
	for _ in 1 2 3 4; do
		echo "$(date +%Y-%m-%dT%H:%M:%S) labapp[4242]: LOGIN FAILED user=intruder src=$TEST_IP reason=badpass" >> "$LOG"
	done
	# Up to 20 seconds for the ban
	for _ in $(seq 1 40); do
		if banned_in_jail; then
			ban_ok=0
			break
		fi
		sleep 0.5
	done
	f2b set labapp unbanip "$TEST_IP" >/dev/null
	f2b stop labapp >/dev/null
	truncate -s "$size" "$LOG"
	f2b reload >/dev/null
	for _ in $(seq 1 20); do
		jail_running && break
		sleep 0.5
	done
fi

criterion "Package fail2ban is installed" rpm -q fail2ban
criterion "Service fail2ban is enabled" systemctl is-enabled --quiet fail2ban
criterion "Service fail2ban is active" systemctl is-active --quiet fail2ban
criterion_result "The fail2ban configuration reloads without errors" "$reload_ok"
criterion "Filter labapp matches the $fails failed logins of the log" \
	regex_matches "$DATA_DIR/auth.log" "$fails"
criterion "Filter labapp matches no other line of the log" \
	regex_matches "$DATA_DIR/other.log" 0
criterion "Jail labapp is defined in /etc/fail2ban/jail.d/*.local" \
	jail_in_jail_d
criterion_result "Jail labapp is running" "$jail_ok"
criterion "Jail labapp reads $LOG" logpath_is_log
criterion "Jail labapp bans port 8443/tcp" actions_port
criterion "Jail labapp has maxretry 3" value_is maxretry 3
criterion "Jail labapp has findtime 10 minutes" value_is findtime 600
criterion "Jail labapp has bantime 30 minutes" value_is bantime 1800
criterion "Jail labapp ignores 127.0.0.1/8 and ::1" loopback_ignored
criterion "Jail labapp ignores the network $net" covers "$net"
criterion_result "New failed logins from $TEST_IP get it banned" "$ban_ok"
grade_end
