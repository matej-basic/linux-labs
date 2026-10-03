#!/bin/bash
# systemd-11 cleanup: remove the lab's sysctl and tmpfiles.d files and
# directories, put /etc/sysctl.conf, /etc/sysctl.d and /etc/tmpfiles.d
# back to the copy setup.sh recorded, and set the recorded runtime
# values of the kernel parameters again. No reboot. Safe on a system
# where the lab never ran.
LAB=systemd-11
STATE=/opt/linux-labs/state/$LAB
rc=0

rm -f /etc/sysctl.d/80-labtune.conf /etc/sysctl.d/99-zz-legacy.conf \
	/etc/tmpfiles.d/labapp.conf
rm -rf /run/labapp /var/tmp/labcache

# restore_dir <copy> <dir>: files added since the copy are removed,
# changed and removed files are written back
restore_dir() {
	local copy=$1 dir=$2 f name
	[ -d "$copy" ] || return 0
	for f in "$dir"/* "$dir"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		name=${f##*/}
		[ -e "$copy/$name" ] || [ -L "$copy/$name" ] || rm -rf "$f"
	done
	for f in "$copy"/* "$copy"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		name=${f##*/}
		if [ -L "$f" ]; then
			# A symbolic link (99-sysctl.conf points to ../sysctl.conf)
			if [ ! -L "$dir/$name" ] ||
				[ "$(readlink "$f")" != "$(readlink "$dir/$name")" ]; then
				rm -rf "${dir:?}/$name"
				cp -a "$f" "$dir/$name" || return 1
			fi
		elif [ ! -f "$f" ]; then
			# Anything else only comes back when it is missing
			[ -e "$dir/$name" ] || cp -a "$f" "$dir/$name" || return 1
		elif [ -f "$dir/$name" ] && [ ! -L "$dir/$name" ]; then
			# Restored with cat so that owner, mode and label stay
			cmp -s "$f" "$dir/$name" || cat "$f" > "$dir/$name" || return 1
		else
			rm -rf "${dir:?}/$name"
			cp -a "$f" "$dir/$name" || return 1
			restorecon "$dir/$name" 2>/dev/null || true
		fi
	done
}

if [ -f "$STATE/baseline" ]; then
	restore_dir "$STATE/sysctl.d" /etc/sysctl.d || rc=1
	restore_dir "$STATE/tmpfiles.d" /etc/tmpfiles.d || rc=1
	if [ -f "$STATE/sysctl.conf" ] && ! cmp -s "$STATE/sysctl.conf" /etc/sysctl.conf; then
		cat "$STATE/sysctl.conf" > /etc/sysctl.conf || rc=1
	fi
	while IFS='=' read -r key value; do
		[ -n "$key" ] || continue
		sysctl -q -w "$key=$value" >/dev/null 2>&1 || rc=1
	done < "$STATE/runtime"
fi

# Keep the record when the restore failed, so it can be done by hand
if [ "$rc" -eq 0 ]; then
	rm -rf "$STATE"
else
	echo "$LAB: the recorded configuration is kept in $STATE" >&2
fi
exit "$rc"
