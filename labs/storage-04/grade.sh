#!/bin/bash
# storage-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/storage-04
SWAPFILE=/swapfile
SYSCTL_FILE=/etc/sysctl.d/90-swappiness.conf
PRIO=10
SWAPPINESS=20
PROFILE=throughput-performance

grade_begin storage-04
grade_require_state storage-04 "$STATE_FILE"
old_swaps=$(sed -n 's/^swaps=//p' "$STATE_FILE" | head -n 1)

# swap_field <column>: the column of the swap area $SWAPFILE in swapon
swap_field() {
	swapon --show=NAME,SIZE,PRIO --bytes --noheadings --raw 2>/dev/null |
		awk -v f="$SWAPFILE" -v c="$1" '$1 == f { print $c; exit }'
}

file_secure() {
	[ -f "$SWAPFILE" ] || return 1
	[ "$(stat -c '%a %U' "$SWAPFILE" 2>/dev/null)" = "600 root" ]
}

swap_active() {
	[ -n "$(swap_field 1)" ]
}

# 512 MiB, graded as 496 to 528 MiB
swap_size_ok() {
	local size
	size=$(swap_field 2)
	[ -n "$size" ] || return 1
	[ "$size" -ge $((496 * 1048576)) ] && [ "$size" -le $((528 * 1048576)) ]
}

swap_prio_ok() {
	[ "$(swap_field 3)" = "$PRIO" ]
}

# Every swap area that was active at the first start is still active
old_swaps_active() {
	local active s
	active=$(swapon --show=NAME --noheadings --raw 2>/dev/null |
		while read -r s; do readlink -f "$s"; done)
	for s in $old_swaps; do
		printf '%s\n' "$active" | grep -qxF "$(readlink -f "$s")" || return 1
	done
}

# fstab_option <option>: an active fstab line for $SWAPFILE of type swap
# has the option (no argument: the line exists)
fstab_option() {
	awk -v f="$SWAPFILE" -v want="${1:-}" '
		/^[[:space:]]*#/ { next }
		$1 == f && $3 == "swap" {
			if (want == "") found = 1
			n = split($4, o, ",")
			for (i = 1; i <= n; i++) if (o[i] == want) found = 1
		}
		END { exit !found }' /etc/fstab
}

fstab_entry() {
	fstab_option
}

fstab_options() {
	fstab_option "pri=$PRIO" && fstab_option nofail
}

swappiness_runtime() {
	[ "$(sysctl -n vm.swappiness 2>/dev/null)" = "$SWAPPINESS" ]
}

# The last vm.swappiness setting in the file is the value
swappiness_file() {
	[ -f "$SYSCTL_FILE" ] || return 1
	[ "$(awk -F= '
		/^[[:space:]]*[#;]/ { next }
		{
			k = $1; gsub(/[[:space:]]/, "", k)
			v = $2; gsub(/[[:space:]]/, "", v)
			if (k == "vm.swappiness" || k == "vm/swappiness") val = v
		}
		END { print val }' "$SYSCTL_FILE")" = "$SWAPPINESS" ]
}

tuned_running() {
	systemctl is-enabled --quiet tuned && systemctl is-active --quiet tuned
}

tuned_profile() {
	[ "$(head -n 1 /etc/tuned/active_profile 2>/dev/null)" = "$PROFILE" ] || return 1
	tuned-adm active 2>/dev/null |
		grep -qx "Current active profile: $PROFILE"
}

criterion "File $SWAPFILE exists with mode 600, owned by root" file_secure
criterion "$SWAPFILE is active as swap space" swap_active
criterion "Swap space $SWAPFILE is 512 MiB" swap_size_ok
criterion "Swap space $SWAPFILE has priority $PRIO" swap_prio_ok
criterion "The swap space active at the start is still active" old_swaps_active
criterion "fstab activates $SWAPFILE as swap space" fstab_entry
criterion "That fstab entry has the options pri=$PRIO and nofail" fstab_options
criterion "vm.swappiness is $SWAPPINESS at runtime" swappiness_runtime
criterion "$SYSCTL_FILE sets vm.swappiness to $SWAPPINESS" swappiness_file
criterion "tuned is enabled and running" tuned_running
criterion "Active tuned profile is $PROFILE" tuned_profile
grade_end
