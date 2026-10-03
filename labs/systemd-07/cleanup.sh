#!/bin/bash
# systemd-07 cleanup: remove the dump directory, restore the package set
# (kexec-tools comes back if it was installed at the first start), then
# the boot configuration recorded by setup.sh byte for byte, the kdump
# configuration and the enabled and active state of kdump. No reboot:
# the crash kernel memory of the running kernel stays until the next
# boot. Safe on a system where the lab never ran.
source /opt/linux-labs/lib/packages.sh

LAB=systemd-07
STATE=/opt/linux-labs/state/$LAB
ENTRIES=/boot/loader/entries
rc=0

rm -rf /var/crash/lab

pkg_restore "$LAB" || rc=1

if [ -f "$STATE/baseline" ]; then
	# Files are restored with cat so that owner, mode and SELinux
	# label of the target stay as they are. Installing kexec-tools on
	# Rocky Linux 9 changes the crashkernel argument, so the boot
	# configuration comes after pkg_restore.
	cat "$STATE/default-grub" > /etc/default/grub || rc=1
	grub_cfg=$(cat "$STATE/grub-cfg-path" 2>/dev/null)
	if [ -n "$grub_cfg" ] && [ -f "$STATE/grub.cfg" ]; then
		cat "$STATE/grub.cfg" > "$grub_cfg" || rc=1
	fi
	for f in "$STATE"/entries/*.conf; do
		[ -f "$f" ] || continue
		# An entry of a kernel removed during the lab stays removed
		[ -f "$ENTRIES/${f##*/}" ] || continue
		cat "$f" > "$ENTRIES/${f##*/}" || rc=1
	done
	if [ -f "$STATE/grubenv-kernelopts" ]; then
		grub2-editenv - set "kernelopts=$(cat "$STATE/grubenv-kernelopts")" || rc=1
	elif grub2-editenv list 2>/dev/null | grep -q '^kernelopts='; then
		grub2-editenv - unset kernelopts || rc=1
	fi

	# Every kernel recorded at the start must have its original
	# arguments again
	current=$(grubby --info=ALL 2>/dev/null |
		awk '/^kernel=/ { k = $0 } /^args=/ { print k "|" $0 }')
	while IFS= read -r pair; do
		[ -n "$pair" ] || continue
		kernel=${pair%%|*}
		printf '%s\n' "$current" | grep -q "^$kernel|" || continue
		if ! printf '%s\n' "$current" | grep -qxF "$pair"; then
			echo "$LAB: the arguments of $kernel differ from the start of the lab" >&2
			rc=1
		fi
	done < <(awk '/^kernel=/ { k = $0 } /^args=/ { print k "|" $0 }' "$STATE/grubby-info")

	# The kdump configuration, if the package is there again
	if rpm -q kexec-tools >/dev/null 2>&1; then
		[ ! -f "$STATE/kdump.conf" ] || cat "$STATE/kdump.conf" > /etc/kdump.conf || rc=1
		[ ! -f "$STATE/sysconfig-kdump" ] ||
			cat "$STATE/sysconfig-kdump" > /etc/sysconfig/kdump || rc=1
	fi
	# Configuration files saved by a package removal during the lab
	for f in /etc/kdump.conf.rpmsave /etc/sysconfig/kdump.rpmsave; do
		[ -e "$f" ] || continue
		grep -qxF "$f" "$STATE/rpmsave" 2>/dev/null || rm -f "$f"
	done

	# The kdump service as it was. Starting it needs crash kernel
	# memory in the running kernel; without it kdump starts at the
	# next boot.
	if systemctl cat kdump >/dev/null 2>&1; then
		if [ -f "$STATE/kdump-enabled" ]; then
			systemctl enable kdump >/dev/null 2>&1 || rc=1
		else
			systemctl disable kdump >/dev/null 2>&1 || rc=1
		fi
		if [ -f "$STATE/kdump-active" ]; then
			if ! systemctl restart kdump >/dev/null 2>&1; then
				echo "$LAB: kdump does not start now; it starts after the next reboot" >&2
			fi
		else
			systemctl stop kdump >/dev/null 2>&1 || true
		fi
	fi
fi

# Keep the record when the restore failed, so it can be done by hand
if [ "$rc" -eq 0 ]; then
	rm -rf "$STATE"
else
	echo "$LAB: the recorded configuration is kept in $STATE" >&2
fi
exit "$rc"
