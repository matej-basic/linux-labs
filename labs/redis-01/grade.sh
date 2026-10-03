#!/bin/bash
# redis-01 grader. Checks the running Redis with redis-cli and ss only,
# never the configuration file, then restarts redis and checks that the
# password, AOF persistence, the memory limit and the key survive.
source /opt/linux-labs/lib/grading.sh

LAB=redis-01
STATE_FILE=/opt/linux-labs/state/$LAB
PASSWORD=labredis42

grade_begin redis-01
grade_require_state redis-01 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}
addr=$(state_value address)
dev=$(state_value device)
zone=$(firewall-cmd --get-zone-of-interface="$dev" 2>/dev/null)
[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone 2>/dev/null)

# Host that redis-cli talks to: 127.0.0.1, else the server address, so a
# wrong bind line costs only the listening criteria
host=127.0.0.1

# rcli <args>: redis-cli without a password
rcli() {
	env -u REDISCLI_AUTH timeout 5 redis-cli -h "$host" -p 6379 "$@" 2>&1
}

# acli <args>: redis-cli with the lab password (from the environment,
# so it never shows in the process list)
acli() {
	REDISCLI_AUTH=$PASSWORD timeout 5 redis-cli --no-auth-warning \
		-h "$host" -p 6379 "$@" 2>/dev/null
}

# pick_host: the first address where Redis answers at all
pick_host() {
	local h out
	for h in 127.0.0.1 "$addr"; do
		host=$h
		out=$(rcli PING) || continue
		case $out in
		*PONG* | *NOAUTH* | *DENIED*) return 0 ;;
		esac
	done
	host=127.0.0.1
}

# config_value <name>: the value CONFIG GET returns
config_value() {
	acli CONFIG GET "$1" | sed -n 2p
}

listens_on() {
	ss -H -tln "sport = :6379" 2>/dev/null | awk '{ print $4 }' | grep -qxF "$1:6379"
}

noauth_refused() {
	local out
	out=$(rcli PING)
	case $out in
	*NOAUTH*) return 0 ;;
	esac
	return 1
}

auth_pong() {
	[ "$(acli PING)" = PONG ]
}

aof_on() {
	[ "$(config_value appendonly)" = yes ]
}

# The AOF in the data directory: the appendonly file (Redis 5 and 6) or
# the append-only directory (Redis 7)
aof_exists() {
	local dir file adir
	dir=$(config_value dir)
	file=$(config_value appendfilename)
	adir=$(config_value appenddirname)
	[ -n "$dir" ] || return 1
	if [ -n "$adir" ]; then
		[ -d "$dir/$adir" ] && [ -n "$(ls -A "$dir/$adir" 2>/dev/null)" ]
	elif [ -n "$file" ]; then
		[ -f "$dir/$file" ]
	else
		# Redis 5 does not report appendfilename
		find "$dir" -maxdepth 1 -type f -name '*.aof' | grep -q .
	fi
}

maxmemory_set() {
	[ "$(config_value maxmemory)" = 134217728 ]
}

policy_set() {
	[ "$(config_value maxmemory-policy)" = allkeys-lru ]
}

key_ready() {
	[ "$(acli GET lab:status)" = ready ]
}

# fw_open [--permanent]: port 6379/tcp or the redis service is open in
# the zone of the default-route interface
fw_open() {
	[ -n "$zone" ] || return 1
	firewall-cmd "$@" --zone="$zone" --query-port=6379/tcp >/dev/null 2>&1 \
		|| firewall-cmd "$@" --zone="$zone" --query-service=redis >/dev/null 2>&1
}

# Restart redis and wait until it answers again
restart_redis() {
	local _
	timeout 60 systemctl restart redis >/dev/null 2>&1 || return 1
	for _ in $(seq 1 20); do
		pick_host
		case $(rcli PING) in
		*PONG* | *NOAUTH*) return 0 ;;
		esac
		sleep 0.5
	done
	return 1
}

pick_host
criterion "Service redis is enabled" systemctl is-enabled --quiet redis
criterion "Service redis is running" systemctl is-active --quiet redis
criterion "Redis listens on 127.0.0.1:6379" listens_on 127.0.0.1
criterion "Redis listens on $addr:6379" listens_on "$addr"
criterion "PING without the password is refused" noauth_refused
criterion "PING with the password labredis42 answers PONG" auth_pong
criterion "appendonly is yes" aof_on
criterion "The append-only file exists in the data directory" aof_exists
criterion "maxmemory is 134217728 bytes (128mb)" maxmemory_set
criterion "maxmemory-policy is allkeys-lru" policy_set
criterion "Key lab:status has the value ready" key_ready
criterion "Port 6379/tcp is open in the running firewall" fw_open
criterion "Port 6379/tcp is open in the permanent firewall" fw_open --permanent

rc=1
restart_redis && rc=0
criterion_result "Service redis restarts" "$rc"
after_restart_policy() {
	maxmemory_set && policy_set
}
criterion "After a restart, the password is required" noauth_refused
criterion "After a restart, appendonly is yes" aof_on
criterion "After a restart, the memory limit and policy are set" after_restart_policy
criterion "After a restart, lab:status has the value ready" key_ready
grade_end
