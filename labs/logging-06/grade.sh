#!/bin/bash
# logging-06 grader
source /opt/linux-labs/lib/grading.sh

STATE_DIR=/opt/linux-labs/state/logging-06
CONF=/etc/systemd/journald.conf
DROPIN_DIR=/etc/systemd/journald.conf.d
JDIR=/var/log/journal
TAG=labjournal
MSG="journald limits applied"

grade_begin logging-06
grade_require_state logging-06 "$STATE_DIR/journal"

mid=$(cat /etc/machine-id 2>/dev/null)

# The effective journald configuration: every Key=value line of
# journald.conf and its drop-ins in the order systemd reads them, so
# the last value of a key wins.
effective=$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null |
	sed -n 's/^[[:space:]]*\([A-Za-z]*\)[[:space:]]*=[[:space:]]*\(.*\)$/\1=\2/p' |
	sed 's/[[:space:]]*$//')

# value <key>...: the last value of any of the keys
value() {
	local re
	re=$(printf '%s|' "$@")
	re=${re%|}
	printf '%s\n' "$effective" | sed -n -E "s/^($re)=//p" | tail -n 1
}

# bytes <size>: a journald size (1024-based K, M, G, T) in bytes
bytes() {
	local v=$1 n u
	[[ $v =~ ^([0-9]+)[[:space:]]*([KMGT]?)B?$ ]] || return 1
	n=${BASH_REMATCH[1]}
	u=${BASH_REMATCH[2]}
	case $u in
	K) n=$((n * 1024)) ;;
	M) n=$((n * 1024 * 1024)) ;;
	G) n=$((n * 1024 * 1024 * 1024)) ;;
	T) n=$((n * 1024 * 1024 * 1024 * 1024)) ;;
	esac
	echo "$n"
}

# seconds <time span>: a systemd time span (man systemd.time) in seconds
seconds() {
	local v total=0 n u f
	v=$(printf '%s' "$1" | sed -E 's/([0-9])[[:space:]]+([a-zA-Z])/\1\2/g')
	[ -n "$v" ] || return 1
	for f in $v; do
		[[ $f =~ ^([0-9]+)([a-zA-Z]*)$ ]] || return 1
		n=${BASH_REMATCH[1]}
		u=${BASH_REMATCH[2]}
		case $u in
		'' | s | sec | second | seconds) ;;
		m | min | minute | minutes) n=$((n * 60)) ;;
		h | hr | hour | hours) n=$((n * 3600)) ;;
		d | day | days) n=$((n * 86400)) ;;
		w | week | weeks) n=$((n * 604800)) ;;
		*) return 1 ;;
		esac
		total=$((total + n))
	done
	echo "$total"
}

is_bytes() {
	[ "$(bytes "$(value "$1")")" = "$2" ]
}

is_seconds() {
	local key=$1 want=$2
	shift 2
	[ "$(seconds "$(value "$key" "$@")")" = "$want" ]
}

dropin_exists() {
	compgen -G "$DROPIN_DIR/*.conf" >/dev/null
}

conf_unchanged() {
	cmp -s "$STATE_DIR/journald.conf" "$CONF"
}

# journald is active and its current instance started at or after the
# newest change in the drop-in directory.
restarted_after_dropin() {
	local ts started newest
	systemctl is-active --quiet systemd-journald || return 1
	dropin_exists || return 1
	ts=$(systemctl show -p ActiveEnterTimestamp --value systemd-journald)
	started=$(date -d "$ts" +%s) || return 1
	newest=$(stat -c %Y "$DROPIN_DIR" "$DROPIN_DIR"/*.conf | sort -n | tail -n 1)
	[ "$started" -ge "$newest" ]
}

persistent_files() {
	[ -n "$mid" ] && [ -f "$JDIR/$mid/system.journal" ]
}

# The running journald reported its system journal below /var/log/journal
# with a maximum use of 100.0M.
max_use_applied() {
	local pid line
	pid=$(systemctl show -p MainPID --value systemd-journald)
	[ -n "$pid" ] && [ "$pid" != 0 ] || return 1
	line=$(journalctl -b -t systemd-journald _PID="$pid" -o cat 2>/dev/null |
		grep -i '^System journal (/var/log/journal/' | tail -n 1)
	[[ $line == *", max 100.0M,"* ]]
}

msg_in_journal() {
	[ -n "$mid" ] && [ -d "$JDIR/$mid" ] || return 1
	journalctl -D "$JDIR/$mid" -t "$TAG" -o cat 2>/dev/null |
		grep -qxF "$MSG"
}

# The newest such line in /var/log/messages was written at or after the
# start of the running journald (the traditional format has no year).
msg_in_messages() {
	local line ts when started
	line=$(grep -E "[[:space:]]$TAG(\[[0-9]+\])?: $MSG\$" /var/log/messages |
		tail -n 1)
	[ -n "$line" ] || return 1
	ts=$(printf '%s\n' "$line" | awk '{ print $1, $2, $3 }')
	when=$(date -d "$ts" +%s) || return 1
	[ "$when" -le "$(($(date +%s) + 86400))" ] ||
		when=$(date -d "$ts last year" +%s) || return 1
	started=$(date -d "$(systemctl show -p ActiveEnterTimestamp --value \
		systemd-journald)" +%s) || return 1
	[ "$when" -ge "$started" ]
}

criterion "A drop-in file exists in $DROPIN_DIR" dropin_exists
criterion "$CONF is unchanged" conf_unchanged
rc=1
[ "$(value Storage)" = persistent ] && rc=0
criterion_result "Effective Storage is persistent" "$rc"
criterion "Effective SystemMaxUse is 100M" is_bytes SystemMaxUse 104857600
criterion "Effective SystemMaxFileSize is 20M" \
	is_bytes SystemMaxFileSize 20971520
criterion "Effective RateLimitIntervalSec is 10s" \
	is_seconds RateLimitIntervalSec 10 RateLimitInterval
rc=1
[ "$(value RateLimitBurst)" = 500 ] && rc=0
criterion_result "Effective RateLimitBurst is 500" "$rc"
criterion "Effective MaxRetentionSec is 2 weeks" \
	is_seconds MaxRetentionSec 1209600
criterion "systemd-journald was restarted after the drop-in change" \
	restarted_after_dropin
criterion "Journal files are written below $JDIR/<machine-id>" \
	persistent_files
criterion "Running journald limits the system journal to 100M" \
	max_use_applied
criterion "Message from $TAG is in the persistent journal" msg_in_journal
criterion "Message from $TAG is in /var/log/messages" msg_in_messages
grade_end
