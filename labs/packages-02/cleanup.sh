#!/bin/bash
# packages-02 cleanup: remove what the lab and its solution installed
# (htop, EPEL) and restore what was installed before the lab started.
# EPEL stays available to other labs only if it was there before.
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-02"
BACKUP_DIR="$STATE_DIR/packages-02.repos"

epel_pre=no
htop_pre=no
if [ -r "$STATE_FILE" ]; then
	grep -qx 'epel_pre=yes' "$STATE_FILE" && epel_pre=yes
	grep -qx 'htop_pre=yes' "$STATE_FILE" && htop_pre=yes
fi

rpm -q htop >/dev/null 2>&1 && dnf -y -q remove htop >/dev/null 2>&1
rpm -q epel-release >/dev/null 2>&1 && dnf -y -q remove epel-release >/dev/null 2>&1
rm -f /etc/yum.repos.d/epel*.repo
# The EPEL signing key stays in the rpm database after the removal
if [ "$epel_pre" = no ]; then
	for k in $(rpm -qa 'gpg-pubkey*' --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SUMMARY}\n' 2>/dev/null | awk '/EPEL/ { print $1 }'); do
		rpm -e "$k" >/dev/null 2>&1
	done
fi

if [ "$epel_pre" = yes ]; then
	# Put EPEL back as it was, including local edits to the repo files
	dnf -y -q install epel-release >/dev/null 2>&1
	if [ -d "$BACKUP_DIR" ]; then
		cp -p "$BACKUP_DIR"/*.repo /etc/yum.repos.d/ 2>/dev/null
	fi
	[ "$htop_pre" = yes ] && dnf -y -q install htop >/dev/null 2>&1
elif [ "$htop_pre" = yes ]; then
	# htop came from EPEL before the lab: use EPEL once, then drop it again
	if dnf -y -q install epel-release >/dev/null 2>&1; then
		dnf -y -q install htop >/dev/null 2>&1
		dnf -y -q remove epel-release >/dev/null 2>&1
	fi
	rm -f /etc/yum.repos.d/epel*.repo
fi

rm -rf "$STATE_FILE" "$BACKUP_DIR"
exit 0
