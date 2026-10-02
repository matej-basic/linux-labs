#!/bin/bash
# packages-04 cleanup: put joe back as it was before the first setup.sh
# run, remove downloaded joe RPM files, repo keys imported during the
# lab, and the state file.
PRE=/var/tmp/packages-04.pre

rpm -q joe &>/dev/null && dnf -y remove joe &>/dev/null
if [ -f "$PRE" ]; then
	if grep -qx joe-installed "$PRE"; then
		dnf -y install joe &>/dev/null || true
	fi
	for k in $(rpm -qa 'gpg-pubkey*'); do
		grep -qx "key $k" "$PRE" || rpm -e "$k" &>/dev/null || true
	done
	rm -f "$PRE"
fi

user=${LAB_USER:-student}
getent passwd "$user" &>/dev/null || user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
user_home=$(getent passwd "$user" | cut -d: -f6)
for dir in /tmp /root "$user_home"; do
	[ -n "$dir" ] && [ -d "$dir" ] || continue
	find "$dir" -maxdepth 1 -type f -name 'joe*.rpm' -delete 2>/dev/null
done

rm -f /opt/linux-labs/state/packages-04
exit 0
