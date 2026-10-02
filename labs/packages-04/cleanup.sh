#!/bin/bash
# packages-04 cleanup: remove downloaded joe RPM files and the state
# file. pkg_restore removes joe and repo keys imported during the lab, or
# puts joe back if it was installed at the first start.
source /opt/linux-labs/lib/packages.sh

user=${LAB_USER:-student}
getent passwd "$user" &>/dev/null || user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
user_home=$(getent passwd "$user" | cut -d: -f6)
for dir in /tmp /root "$user_home"; do
	[ -n "$dir" ] && [ -d "$dir" ] || continue
	find "$dir" -maxdepth 1 -type f -name 'joe*.rpm' -delete 2>/dev/null
done

rm -f /opt/linux-labs/state/packages-04
rc=0
pkg_restore packages-04 || rc=1
exit "$rc"
