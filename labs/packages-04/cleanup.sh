#!/bin/bash
# packages-04 cleanup: remove joe, downloaded joe RPM files and the state file.

rpm -q joe &>/dev/null && dnf -y remove joe &>/dev/null

user_home=$(getent passwd "${SUDO_USER:-student}" | cut -d: -f6)
for dir in /tmp /root "$user_home"; do
	[ -n "$dir" ] && [ -d "$dir" ] || continue
	find "$dir" -maxdepth 1 -type f -name 'joe*.rpm' -delete 2>/dev/null
done

rm -f /opt/linux-labs/state/packages-04
exit 0
