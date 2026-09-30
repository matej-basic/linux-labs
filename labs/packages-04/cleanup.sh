#!/bin/bash
# Package Management Lab 04: Cleanup

rpm -q joe &>/dev/null && dnf -y remove joe &>/dev/null

user_home=$(getent passwd "${SUDO_USER:-student}" | cut -d: -f6)
for dir in /tmp /root "$user_home"; do
	[[ -n "$dir" && -d "$dir" ]] || continue
	find "$dir" -maxdepth 1 -type f -name 'joe-*.rpm' -delete 2>/dev/null
done

rm -f /opt/linux-labs/state/packages-04

echo "Cleanup complete. The joe package and downloaded joe RPM files are removed."
exit 0
