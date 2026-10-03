#!/bin/bash
# systemd-11 grader
source /opt/linux-labs/lib/grading.sh

STATE=/opt/linux-labs/state/systemd-11
TUNE=/etc/sysctl.d/80-labtune.conf
LEGACY=/etc/sysctl.d/99-zz-legacy.conf
TMPCONF=/etc/tmpfiles.d/labapp.conf
RUNDIR=/run/labapp
CACHE=/var/tmp/labcache

grade_begin systemd-11
grade_require_state systemd-11 "$STATE/baseline"
owner=$(cat "$STATE/owner" 2>/dev/null)
owner=${owner:-${LAB_USER:-student}}

# sysctl_file_value <file> <key>: the last value the file sets for the
# key, with "/" or "." as separator and an optional "-" before the key
sysctl_file_value() {
	awk -v want="$2" '
		/^[[:space:]]*([#;]|$)/ { next }
		{
			i = index($0, "=")
			if (i == 0) next
			k = substr($0, 1, i - 1); v = substr($0, i + 1)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
			sub(/^-/, "", k)
			gsub(/\//, ".", k)
			if (k == want) { val = v; found = 1 }
		}
		END { if (found) print val; exit !found }' "$1" 2>/dev/null
}

file_sets() {
	[ -f "$1" ] && [ "$(sysctl_file_value "$1" "$2")" = "$3" ]
}

runtime_is() {
	[ "$(sysctl -n "$1" 2>/dev/null)" = "$2" ]
}

# The sysctl files applied at boot, in order: every *.conf of the four
# directories, the first directory wins for a name, sorted by name
sysctl_files_in_order() {
	local d f name
	declare -A seen=()
	for d in /etc/sysctl.d /run/sysctl.d /usr/local/lib/sysctl.d /usr/lib/sysctl.d; do
		for f in "$d"/*.conf; do
			[ -e "$f" ] || continue
			name=${f##*/}
			[ -z "${seen[$name]:-}" ] || continue
			seen[$name]=$f
		done
	done
	for name in "${!seen[@]}"; do
		printf '%s\t%s\n' "$name" "${seen[$name]}"
	done | LC_ALL=C sort | cut -f 2
}

# No file applied after 80-labtune.conf sets one of the three keys
not_overridden() {
	local f after=0 key
	[ -f "$TUNE" ] || return 1
	while IFS= read -r f; do
		if [ "$f" = "$TUNE" ]; then
			after=1
			continue
		fi
		[ "$after" = 1 ] || continue
		for key in fs.inotify.max_user_watches net.core.somaxconn kernel.panic; do
			sysctl_file_value "$f" "$key" >/dev/null && return 1
		done
	done < <(sysctl_files_in_order)
	[ "$after" = 1 ]
}

rebooted_since_start() {
	[ "$(cat /proc/sys/kernel/random/boot_id)" != "$(cat "$STATE/boot-id")" ]
}

# systemd-tmpfiles parses the file in a scratch root with a copy of the
# user and group databases, so nothing changes on the live system. It
# exits non-zero for any line it cannot parse.
tmpfiles_valid() {
	local root rc
	[ -f "$TMPCONF" ] || return 1
	root=$(mktemp -d) || return 1
	mkdir -p "$root/etc/tmpfiles.d"
	cp /etc/passwd /etc/group "$root/etc/"
	cp "$TMPCONF" "$root/etc/tmpfiles.d/labapp.conf"
	systemd-tmpfiles --create --root="$root" "$root/etc/tmpfiles.d/labapp.conf" \
		>/dev/null 2>&1
	rc=$?
	rm -rf "$root"
	return "$rc"
}

# rule_fields <path>: type, mode, user, group and age of the last line
# for the path in labapp.conf, type modifiers removed
rule_fields() {
	awk -v p="$1" '
		/^[[:space:]]*(#|$)/ { next }
		{ q = $2; sub(/\/+$/, "", q) }
		q == p {
			t = $1; gsub(/[-!+=~^]/, "", t)
			r = t " " $3 " " $4 " " $5 " " $6
		}
		END { if (r != "") print r; exit r == "" }' "$TMPCONF" 2>/dev/null
}

# A mode field: 0750 and 750 are the same
mode_is() {
	local m=${1#\~}
	[[ $m =~ ^[0-7]{3,4}$ ]] && [ "$((8#$m))" = "$((8#$2))" ]
}

user_is() {
	[ "$1" = "$2" ] || [ "$1" = "$(id -u "$2" 2>/dev/null)" ]
}

# age_seconds <age>: a tmpfiles.d age in seconds (units s, min, h, d, w)
age_seconds() {
	local s=${1#\~} total=0 num unit m
	[ -n "$s" ] || return 1
	while [ -n "$s" ]; do
		[[ $s =~ ^([0-9]+)([a-z]*)(.*)$ ]] || return 1
		num=$((10#${BASH_REMATCH[1]}))
		unit=${BASH_REMATCH[2]}
		s=${BASH_REMATCH[3]}
		case $unit in
		'' | s | sec | second | seconds) m=1 ;;
		m | min | minute | minutes) m=60 ;;
		h | hr | hour | hours) m=3600 ;;
		d | day | days) m=86400 ;;
		w | week | weeks) m=604800 ;;
		*) return 1 ;;
		esac
		total=$((total + num * m))
	done
	echo "$total"
}

rundir_rule() {
	local t mode user group age
	read -r t mode user group age < <(rule_fields "$RUNDIR") || return 1
	case $t in d | D) ;; *) return 1 ;; esac
	mode_is "$mode" 0750 && user_is "$user" "$owner" &&
		{ [ "$group" = root ] || [ "$group" = 0 ]; }
}

cache_rule_mode() {
	local t mode user group age
	read -r t mode user group age < <(rule_fields "$CACHE") || return 1
	case $t in d | D | v | q | Q) ;; *) return 1 ;; esac
	mode_is "$mode" 1777
}

cache_rule_age() {
	local t mode user group age
	read -r t mode user group age < <(rule_fields "$CACHE") || return 1
	[ "$(age_seconds "$age")" = 604800 ]
}

dir_is() {
	[ -d "$1" ] && [ ! -L "$1" ] &&
		[ "$(stat -c '%a %U %G' "$1" 2>/dev/null)" = "$2" ]
}

cache_dir() {
	[ -d "$CACHE" ] && [ ! -L "$CACHE" ] &&
		[ "$(stat -c %a "$CACHE" 2>/dev/null)" = 1777 ]
}

criterion "80-labtune.conf sets fs.inotify.max_user_watches = 524288" \
	file_sets "$TUNE" fs.inotify.max_user_watches 524288
criterion "80-labtune.conf sets net.core.somaxconn = 4096" \
	file_sets "$TUNE" net.core.somaxconn 4096
criterion "80-labtune.conf sets kernel.panic = 10" file_sets "$TUNE" kernel.panic 10
criterion "No sysctl file applied after 80-labtune.conf sets the three" \
	not_overridden
criterion "99-zz-legacy.conf sets vm.vfs_cache_pressure = 150" \
	file_sets "$LEGACY" vm.vfs_cache_pressure 150
criterion "$TMPCONF is accepted by systemd-tmpfiles" tmpfiles_valid
criterion "labapp.conf creates $RUNDIR as 0750 $owner:root" rundir_rule
criterion "labapp.conf creates $CACHE with mode 1777" cache_rule_mode
criterion "labapp.conf cleans $CACHE after 7 days" cache_rule_age
criterion "System has been rebooted since the lab was started" rebooted_since_start
criterion "fs.inotify.max_user_watches is 524288 at runtime" \
	runtime_is fs.inotify.max_user_watches 524288
criterion "net.core.somaxconn is 4096 at runtime" runtime_is net.core.somaxconn 4096
criterion "kernel.panic is 10 at runtime" runtime_is kernel.panic 10
criterion "vm.vfs_cache_pressure is 150 at runtime" runtime_is vm.vfs_cache_pressure 150
criterion "$RUNDIR exists with mode 0750, owner $owner, group root" \
	dir_is "$RUNDIR" "750 $owner root"
criterion "$CACHE exists with mode 1777" cache_dir
grade_end
