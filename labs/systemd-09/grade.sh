#!/bin/bash
# systemd-09 grader. Reads systemctl show, rpm and the sysstat data file;
# the same commands and formats work on Rocky 8 (sysstat 11.7, systemd
# 239) and Rocky 9 (sysstat 12.5, systemd 252).
source /opt/linux-labs/lib/grading.sh

LAB=systemd-09
STATE_FILE=/opt/linux-labs/state/$LAB
LIBEXEC=/usr/local/libexec
TIMER=sysstat-collect.timer
VENDOR=/usr/lib/systemd/system/$TIMER
DROPIN_DIR=/etc/systemd/system/$TIMER.d

grade_begin systemd-09
grade_require_state systemd-09 "$STATE_FILE"

user=$(awk '$1 == "owner" { print $2; exit }' "$STATE_FILE")
user=${user:-${LAB_USER:-student}}
home=$(getent passwd "$user" | cut -d: -f6)
culprit=$home/culprit.txt

# No process runs the program: by process name, or as a script started
# through its interpreter
cpu_hog_gone() {
	! pgrep -x report-cache && ! pgrep -f "^([^ ]*/)?(ba)?sh $LIBEXEC/report-cache"
}
mem_hog_gone() {
	! pgrep -x index-builder && ! pgrep -f "^([^ ]*/)?g?awk -f $LIBEXEC/index-builder"
}

prop() {
	systemctl show -p "$2" --value "$1" 2>/dev/null
}

# The unit still exists and is neither enabled nor running
unit_off() {
	case $(prop "$1" LoadState) in
	loaded | masked) ;;
	*) return 1 ;;
	esac
	case $(systemctl is-enabled "$1" 2>/dev/null) in
	disabled | masked) ;;
	*) return 1 ;;
	esac
	unit_inactive "$1"
}
unit_inactive() {
	case $(prop "$1" ActiveState) in
	inactive | failed) return 0 ;;
	esac
	return 1
}

# The first line of culprit.txt is the timer, and the file belongs to
# the task user
culprit_ok() {
	local line
	[ -f "$culprit" ] || return 1
	[ "$(stat -c %U "$culprit")" = "$user" ] || return 1
	line=$(head -n 1 "$culprit" | tr -d ' \t\r')
	[ "$line" = report-cache.timer ]
}

# The vendor timer file is as the package installed it, and systemd
# loads it rather than a full copy in /etc
vendor_unchanged() {
	[ -f "$VENDOR" ] || return 1
	[ ! -e "/etc/systemd/system/$TIMER" ] || return 1
	[ "$(prop "$TIMER" FragmentPath)" = "$VENDOR" ] || return 1
	! rpm -V sysstat 2>/dev/null | grep -q " $VENDOR\$"
}

# A .conf file in the drop-in directory is loaded by systemd
dropin_loaded() {
	local p
	for p in $(prop "$TIMER" DropInPaths); do
		case "$p" in
		"$DROPIN_DIR"/*.conf) [ -f "$p" ] && return 0 ;;
		esac
	done
	return 1
}

# The timer has exactly one calendar event, every 2 minutes. systemctl
# shows it normalized, so *:0/2 and *:00/02 both give *-*-* *:00/2:00.
every_two_minutes() {
	local cal
	cal=$(prop "$TIMER" TimersCalendar | grep -o 'OnCalendar=[^;]*' |
		sed 's/^OnCalendar=//; s/ *$//')
	[ "$cal" = "*-*-* *:00/2:00" ]
}

# Today's data file has at least two samples: sadf shows one CPU line
# per interval between two samples (restart records are not intervals)
two_samples() {
	local f n
	f=/var/log/sa/sa$(date +%d)
	[ -f "$f" ] || return 1
	n=$(sadf -d "$f" -- -u 2>/dev/null | grep -v '^#' | grep -vc RESTART)
	[ "${n:-0}" -ge 1 ]
}

criterion "The CPU hog process is not running" cpu_hog_gone
criterion "The memory hog process is not running" mem_hog_gone
criterion "The unit that schedules the CPU hog is disabled and inactive" \
	unit_off report-cache.timer
criterion "The service that runs the CPU hog is inactive" \
	unit_inactive report-cache.service
criterion "The service that runs the memory hog is disabled and inactive" \
	unit_off index-builder.service
criterion "culprit.txt of $user names the right unit" culprit_ok
criterion "Package sysstat is installed" rpm -q sysstat
criterion "$TIMER is enabled" systemctl is-enabled --quiet "$TIMER"
criterion "$TIMER is active" systemctl is-active --quiet "$TIMER"
criterion "Vendor unit $TIMER is unchanged" vendor_unchanged
criterion "A drop-in .conf file in $TIMER.d is loaded" dropin_loaded
criterion "$TIMER runs every 2 minutes" every_two_minutes
criterion "Today's sysstat data file has at least two samples" two_samples
grade_end
