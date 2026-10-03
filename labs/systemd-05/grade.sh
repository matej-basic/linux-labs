#!/bin/bash
# systemd-05 grader
source /opt/linux-labs/lib/grading.sh

STATE=/opt/linux-labs/state/systemd-05
ARG=consoleblank=0
TIMEOUT=10

grade_begin systemd-05
grade_require_state systemd-05 "$STATE/baseline"

grub_cfg=$(cat "$STATE/grub-cfg-path" 2>/dev/null)
grub_cfg=${grub_cfg:-/boot/grub2/grub.cfg}

# has_word "<list>" <word>: the space-separated list contains the word
has_word() {
	case " $1 " in
	*" $2 "*) return 0 ;;
	esac
	return 1
}

# Value of the last active VAR= line in /etc/default/grub, quotes removed
default_grub_value() {
	local v
	v=$(sed -n "s/^[[:space:]]*$1=//p" /etc/default/grub 2>/dev/null | tail -n 1)
	v=${v#\"}
	v=${v%\"}
	v=${v#\'}
	v=${v%\'}
	printf '%s' "$v"
}

rebooted_since_start() {
	[ "$(cat /proc/sys/kernel/random/boot_id)" != "$(cat "$STATE/boot-id")" ]
}

every_kernel_has_arg() {
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

default_cmdline_has_arg() {
	has_word "$(default_grub_value GRUB_CMDLINE_LINUX)" "$ARG"
}

running_kernel_has_arg() {
	has_word "$(cat /proc/cmdline)" "$ARG"
}

default_timeout() {
	[ "$(default_grub_value GRUB_TIMEOUT)" = "$TIMEOUT" ]
}

# Every "set timeout=" in the 00_header part of grub.cfg is the value
grub_cfg_timeout() {
	awk -v t="$TIMEOUT" '
		/^### BEGIN \/etc\/grub.d\/00_header ###/ { h = 1; next }
		/^### END \/etc\/grub.d\/00_header ###/ { h = 0 }
		h && $1 == "set" && $2 ~ /^timeout=/ {
			v = $2; sub(/^timeout=/, "", v); gsub(/"/, "", v)
			n++; if (v != t) bad = 1
		}
		END { exit !(n > 0 && !bad) }' "$grub_cfg"
}

# grub.cfg hides the menu when menu_auto_hide has any value
menu_not_hidden() {
	local list
	list=$(grub2-editenv list 2>/dev/null) || return 1
	! printf '%s\n' "$list" | grep -q '^menu_auto_hide=.'
}

dummy_loaded() {
	grep -q '^dummy ' /proc/modules
}

dummy_loaded_at_boot() {
	grep -Eqs '^[[:space:]]*dummy[[:space:]]*$' /etc/modules-load.d/*.conf
}

# modprobe applies the options lines in the order of modprobe -c, so
# the last numdummies= value wins
dummy_option() {
	modprobe -c 2>/dev/null | awk '
		$1 == "options" && $2 == "dummy" {
			for (i = 3; i <= NF; i++)
				if ($i ~ /^numdummies=/) { v = $i; sub(/^numdummies=/, "", v) }
		}
		END { exit !(v == "2") }'
}

# The dummy interfaces are exactly dummy0 and dummy1
dummy_interfaces() {
	local names
	names=$(ip -o link show type dummy 2>/dev/null |
		awk -F': ' '{ sub(/@.*/, "", $2); print $2 }' | sort | tr '\n' ' ')
	[ "$names" = "dummy0 dummy1 " ]
}

pcspkr_blacklisted() {
	modprobe -c 2>/dev/null | grep -qx 'blacklist pcspkr'
}

pcspkr_not_loaded() {
	! grep -q '^pcspkr ' /proc/modules
}

criterion "Every installed kernel has the argument $ARG" every_kernel_has_arg
criterion "GRUB_CMDLINE_LINUX in /etc/default/grub has $ARG" default_cmdline_has_arg
criterion "GRUB_TIMEOUT in /etc/default/grub is $TIMEOUT" default_timeout
criterion "$grub_cfg sets the menu timeout to $TIMEOUT" grub_cfg_timeout
criterion "GRUB environment block does not hide the menu" menu_not_hidden
criterion "Module dummy is loaded at boot from /etc/modules-load.d" dummy_loaded_at_boot
criterion "Effective module option for dummy is numdummies=2" dummy_option
criterion "Module pcspkr is blacklisted" pcspkr_blacklisted
criterion "System has been rebooted since the lab was started" rebooted_since_start
criterion "Running kernel was booted with $ARG" running_kernel_has_arg
criterion "Module dummy is loaded" dummy_loaded
criterion "Dummy interfaces are exactly dummy0 and dummy1" dummy_interfaces
criterion "Module pcspkr is not loaded" pcspkr_not_loaded
grade_end
