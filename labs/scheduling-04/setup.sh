#!/bin/bash
# scheduling-04 setup: install at when it is missing (reset removes it
# again), leave atd disabled and stopped, create the lab users reporter
# and intern, and record what cleanup.sh restores: the at jobs that
# already exist, /etc/at.allow, /etc/at.deny, the state of atd and the
# task user's ~/.bashrc and ~/.bash_profile. A restart of the lab returns
# to the state recorded at the first start. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=scheduling-04
STATE_DIR=/opt/linux-labs/state/$LAB
LAB_USERS="reporter intern"

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

# Task user, as in files-04
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$owner" ] || fail "no regular user for the task"
fi
home=$(getent passwd "$owner" | cut -d: -f6)
[ -d "$home" ] || fail "the home directory of $owner is missing"

pkg_snapshot "$LAB"

first=no
[ -f "$STATE_DIR/started" ] || first=yes

if [ "$first" = yes ]; then
	rm -rf "$STATE_DIR"
	mkdir -p "$STATE_DIR"
	echo "$owner" > "$STATE_DIR/owner"
	# atd before the lab (the unit is missing when at is not installed)
	en=$(systemctl is-enabled atd.service 2>/dev/null) || true
	ac=$(systemctl is-active atd.service 2>/dev/null) || true
	echo "${en:-disabled} ${ac:-inactive}" > "$STATE_DIR/atd"
fi

if ! rpm -q at >/dev/null 2>&1; then
	# dnf reports a repo key import on stderr; show it only on failure
	if ! out=$(dnf -y -q install at </dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		fail "cannot install at (internet access needed)"
	fi
fi
command -v atq >/dev/null 2>&1 || fail "the command atq is missing"

# Ids of the at jobs of all users
job_ids() {
	atq 2>/dev/null | awk '{ print $1 }' | sort
}

# save <file> <name>: copy a file into the state directory or mark it absent
save() {
	if [ -e "$1" ]; then
		cp -p "$1" "$STATE_DIR/$2"
	else
		: > "$STATE_DIR/$2.absent"
	fi
}

# restore <file> <name>: put a saved file back, in place when it exists
restore() {
	if [ -f "$STATE_DIR/$2" ]; then
		if [ -f "$1" ]; then
			cat "$STATE_DIR/$2" > "$1"
			touch -r "$STATE_DIR/$2" "$1"
		else
			cp -p "$STATE_DIR/$2" "$1"
			restorecon "$1" >/dev/null 2>&1 || true
		fi
	elif [ -f "$STATE_DIR/$2.absent" ]; then
		rm -f "$1"
	fi
}

if [ "$first" = yes ]; then
	job_ids > "$STATE_DIR/jobs"
	save /etc/at.allow at.allow
	save /etc/at.deny at.deny
	save "$home/.bashrc" bashrc
	save "$home/.bash_profile" bash_profile
	: > "$STATE_DIR/started"
else
	# Remove what an earlier run or the solution left behind
	for id in $(job_ids | comm -23 - "$STATE_DIR/jobs"); do
		atrm "$id" 2>/dev/null || true
	done
	restore /etc/at.allow at.allow
	restore /etc/at.deny at.deny
	restore "$home/.bashrc" bashrc
	restore "$home/.bash_profile" bash_profile
fi
rm -f "$home/disk-report.txt"

for u in $LAB_USERS; do
	if id "$u" &>/dev/null; then
		pkill -KILL -u "$u" 2>/dev/null || true
		userdel -r "$u" >/dev/null 2>&1 || fail "cannot remove the old user $u"
	fi
	useradd -m "$u" >/dev/null || fail "cannot create the user $u"
done

systemctl disable --now atd.service >/dev/null 2>&1 || true

chmod 755 "$STATE_DIR"
chmod 644 "$STATE_DIR"/*
