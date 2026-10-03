#!/bin/bash
# systemd-05 cleanup: remove the module configuration of the lab, unload
# dummy, and restore the boot configuration recorded by setup.sh byte for
# byte, so that the next boot is the same as before the lab. No reboot.
# Safe on a system where the lab never ran.
LAB=systemd-05
STATE=/opt/linux-labs/state/$LAB
ENTRIES=/boot/loader/entries
rc=0

# Lines about dummy or pcspkr in the module configuration under /etc.
# A file left with no settings is removed.
for f in /etc/modprobe.d/*.conf /etc/modules-load.d/*.conf; do
	[ -f "$f" ] || continue
	grep -Eq '^[^#]*\<(dummy|pcspkr)\>' "$f" || continue
	tmp=$(mktemp) || continue
	grep -Ev '^[^#]*\<(dummy|pcspkr)\>' "$f" > "$tmp" || true
	if grep -Eq '^[[:space:]]*[^#[:space:]]' "$tmp"; then
		cat "$tmp" > "$f"
	else
		rm -f "$f"
	fi
	rm -f "$tmp"
done

# NetworkManager profiles for dummy0 or dummy1 (an alternative solution)
if command -v nmcli >/dev/null 2>&1; then
	nmcli -g UUID,TYPE connection show 2>/dev/null |
		while IFS=: read -r uuid type; do
			[ "$type" = dummy ] || continue
			ifname=$(nmcli -g connection.interface-name connection show "$uuid" 2>/dev/null)
			case $ifname in
			dummy0 | dummy1) nmcli connection delete "$uuid" >/dev/null 2>&1 || true ;;
			esac
		done
fi

# Unloading dummy removes dummy0 and dummy1
modprobe -r dummy 2>/dev/null || true

if [ -f "$STATE/baseline" ]; then
	# The PC speaker driver as it was at the start
	if [ -f "$STATE/pcspkr-loaded" ]; then
		modprobe pcspkr 2>/dev/null || true
	else
		modprobe -r pcspkr 2>/dev/null || true
	fi

	# Files are restored with cat so that owner, mode and SELinux
	# label of the target stay as they are
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
	for key in kernelopts menu_auto_hide; do
		if [ -f "$STATE/grubenv-$key" ]; then
			grub2-editenv - set "$key=$(cat "$STATE/grubenv-$key")" || rc=1
		else
			grub2-editenv - unset "$key" || rc=1
		fi
	done

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
fi

# Keep the record when the restore failed, so it can be done by hand
if [ "$rc" -eq 0 ]; then
	rm -rf "$STATE"
else
	echo "$LAB: the recorded boot configuration is kept in $STATE" >&2
fi
exit "$rc"
