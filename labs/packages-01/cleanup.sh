#!/bin/bash
# packages-01 cleanup: put git back as it was before the lab. Setup
# removed it, the solution installs it. Where git was missing before the
# first setup.sh run it is removed, where it was installed it is
# installed again. The state file goes too.
PRE=/var/tmp/packages-01.pre

if [ -f "$PRE" ]; then
	if grep -qx git-installed "$PRE"; then
		rpm -q git &>/dev/null || dnf -y install git &>/dev/null || true
	elif rpm -q git &>/dev/null; then
		dnf -y remove git &>/dev/null || true
	fi
	rm -f "$PRE"
fi
rm -f /opt/linux-labs/state/packages-01
exit 0
