#!/bin/bash
# systemd-05 setup: undo an earlier run, record the boot configuration
# (/etc/default/grub, grub.cfg, the boot entries, the GRUB environment
# block and the arguments of every kernel) so that cleanup.sh can restore
# it exactly, and hide the GRUB menu automatically on both releases.
# Prints nothing on success.
set -eu

LAB=systemd-05
STATE=/opt/linux-labs/state/$LAB
ENTRIES=/boot/loader/entries

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

# Restore what an earlier run changed, so the baseline is the original.
# cleanup.sh is safe on a system where the lab never ran.
bash "$(dirname "$0")/cleanup.sh" >/dev/null ||
	fail "cannot restore the boot configuration of an earlier run"
[ ! -e "$STATE" ] || fail "$STATE is still present after the cleanup"

for cmd in grubby grub2-editenv grub2-mkconfig modprobe modinfo ip; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing"
done
grep -q '^GRUB_ENABLE_BLSCFG=true' /etc/default/grub 2>/dev/null ||
	fail "GRUB does not use boot loader specification entries"
compgen -G "$ENTRIES/*.conf" >/dev/null || fail "no boot entries in $ENTRIES"
grubby --info=ALL 2>/dev/null | grep -q '^kernel=' ||
	fail "grubby lists no installed kernel"
for mod in dummy pcspkr; do
	modinfo -n "$mod" >/dev/null 2>&1 || fail "the kernel module $mod is missing"
done

# The configuration file the boot loader reads: /boot/grub2/grub.cfg,
# except on an EL8 UEFI system, where the full file is on the ESP
grub_cfg=/boot/grub2/grub.cfg
if [ -d /sys/firmware/efi ]; then
	for f in /boot/efi/EFI/*/grub.cfg; do
		[ -f "$f" ] || continue
		if grep -q '^### BEGIN /etc/grub.d/00_header' "$f"; then
			grub_cfg=$f
		fi
	done
fi
[ -f "$grub_cfg" ] || fail "cannot find the GRUB configuration file"

# Record the baseline; the file "baseline" is written last and marks a
# complete record for cleanup.sh and the grader
mkdir -p "$STATE/entries"
chmod 755 "$STATE" "$STATE/entries"
cp -p /etc/default/grub "$STATE/default-grub"
cp -p "$grub_cfg" "$STATE/grub.cfg"
cp -p "$ENTRIES"/*.conf "$STATE/entries/"
printf '%s\n' "$grub_cfg" > "$STATE/grub-cfg-path"
grubby --info=ALL > "$STATE/grubby-info" 2>/dev/null
env_list=$(grub2-editenv list)
for key in kernelopts menu_auto_hide; do
	if printf '%s\n' "$env_list" | grep -q "^$key="; then
		printf '%s\n' "$env_list" | sed -n "s/^$key=//p" | head -n 1 |
			tr -d '\n' > "$STATE/grubenv-$key"
	fi
done
if grep -q '^pcspkr ' /proc/modules; then
	touch "$STATE/pcspkr-loaded"
fi
cat /proc/sys/kernel/random/boot_id > "$STATE/boot-id"
chmod 644 "$STATE"/grubby-info "$STATE"/grub-cfg-path "$STATE"/boot-id
echo "$LAB baseline recorded $(date '+%F %T')" > "$STATE/baseline"
chmod 644 "$STATE/baseline"

# Starting point: the GRUB menu is hidden automatically (the Rocky 9
# default) and the PC speaker driver is loaded
grub2-editenv - set menu_auto_hide=1
modprobe pcspkr 2>/dev/null || true
