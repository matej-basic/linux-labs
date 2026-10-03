#!/bin/bash
# systemd-07 grader
source /opt/linux-labs/lib/grading.sh

STATE=/opt/linux-labs/state/systemd-07
ARG=crashkernel=256M
CONF=/etc/kdump.conf
DUMP_DIR=/var/crash/lab
COLLECTOR="makedumpfile -l --message-level 7 -d 17"

grade_begin systemd-07
grade_require_state systemd-07 "$STATE/baseline"

# has_word "<list>" <word>: the space-separated list contains the word
has_word() {
	case " $1 " in
	*" $2 "*) return 0 ;;
	esac
	return 1
}

every_entry_has_arg() {
	local line args n=0
	while IFS= read -r line; do
		case $line in
		args=*) ;;
		*) continue ;;
		esac
		args=${line#args=\"}
		args=${args%\"}
		n=$((n + 1))
		has_word "$args" "$ARG" || return 1
	done < <(grubby --info=ALL 2>/dev/null)
	[ "$n" -gt 0 ]
}

running_kernel_has_arg() {
	has_word "$(cat /proc/cmdline)" "$ARG"
}

crash_kernel_loaded() {
	[ "$(cat /sys/kernel/kexec_crash_loaded 2>/dev/null)" = 1 ]
}

# conf_values <option>: the values of the active lines of the option in
# kdump.conf, comments removed and blanks squeezed, one per line
conf_values() {
	sed -e 's/#.*//' "$CONF" 2>/dev/null |
		awk -v k="$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print }'
}

# The option is set exactly once, to the value
conf_is() {
	[ "$(conf_values "$1")" = "$2" ]
}

criterion "Package kexec-tools is installed" rpm -q kexec-tools
criterion "Every boot entry has the argument $ARG" every_entry_has_arg
criterion "Running kernel was booted with $ARG" running_kernel_has_arg
criterion "Dump path in $CONF is $DUMP_DIR" conf_is path "$DUMP_DIR"
criterion "core_collector is $COLLECTOR" conf_is core_collector "$COLLECTOR"
criterion "Directory $DUMP_DIR exists" test -d "$DUMP_DIR"
criterion "kdump is enabled" systemctl is-enabled kdump
criterion "kdump is active" systemctl is-active kdump
criterion "Crash kernel is loaded" crash_kernel_loaded
grade_end
