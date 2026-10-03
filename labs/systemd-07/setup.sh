#!/bin/bash
# systemd-07 setup: record the boot configuration (/etc/default/grub,
# grub.cfg, the boot entries, kernelopts in the GRUB environment block
# and the arguments of every kernel), the kdump configuration and the
# state of the kdump service, so that cleanup.sh can restore all of it.
# Then set the same starting point on both releases: kexec-tools is not
# installed, kdump is off and no kernel has a crashkernel argument.
# The memory reserved by the running kernel stays until the next boot.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=systemd-07
STATE=/opt/linux-labs/state/$LAB
ENTRIES=/boot/loader/entries
DUMP_DIR=/var/crash/lab

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

for cmd in grubby grub2-editenv systemctl dnf; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing"
done
grep -q '^GRUB_ENABLE_BLSCFG=true' /etc/default/grub 2>/dev/null ||
	fail "GRUB does not use boot loader specification entries"
compgen -G "$ENTRIES/*.conf" >/dev/null || fail "no boot entries in $ENTRIES"
grubby --info=ALL 2>/dev/null | grep -q '^kernel=' ||
	fail "grubby lists no installed kernel"
[ -e /sys/kernel/kexec_crash_loaded ] ||
	fail "the kernel does not support kexec crash kernels"

pkg_snapshot "$LAB" || fail "cannot record the package set"

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

# Record the baseline on the first start only; a restarted lab keeps
# the record of its first start. The file "baseline" is written last
# and marks a complete record for cleanup.sh and the grader.
if [ ! -f "$STATE/baseline" ]; then
	rm -rf "$STATE"
	mkdir -p "$STATE/entries"
	chmod 755 "$STATE" "$STATE/entries"
	cp -p /etc/default/grub "$STATE/default-grub"
	if [ -f "$grub_cfg" ]; then
		cp -p "$grub_cfg" "$STATE/grub.cfg"
		printf '%s\n' "$grub_cfg" > "$STATE/grub-cfg-path"
	fi
	cp -p "$ENTRIES"/*.conf "$STATE/entries/"
	grubby --info=ALL > "$STATE/grubby-info" 2>/dev/null
	if grub2-editenv list 2>/dev/null | grep -q '^kernelopts='; then
		grub2-editenv list | sed -n 's/^kernelopts=//p' | head -n 1 |
			tr -d '\n' > "$STATE/grubenv-kernelopts"
	fi
	[ ! -f /etc/kdump.conf ] || cp -p /etc/kdump.conf "$STATE/kdump.conf"
	[ ! -f /etc/sysconfig/kdump ] || cp -p /etc/sysconfig/kdump "$STATE/sysconfig-kdump"
	for f in /etc/kdump.conf.rpmsave /etc/sysconfig/kdump.rpmsave; do
		[ ! -e "$f" ] || echo "$f" >> "$STATE/rpmsave"
	done
	if systemctl is-enabled kdump >/dev/null 2>&1; then
		touch "$STATE/kdump-enabled"
	fi
	if systemctl is-active kdump >/dev/null 2>&1; then
		touch "$STATE/kdump-active"
	fi
	find "$STATE" -type f -exec chmod 644 {} +
	echo "$LAB baseline recorded $(date '+%F %T')" > "$STATE/baseline"
	chmod 644 "$STATE/baseline"
fi

# Starting point: no dump directory, kdump off and not installed
rm -rf "$DUMP_DIR"
systemctl disable --now kdump >/dev/null 2>&1 || true
if rpm -q kexec-tools >/dev/null 2>&1; then
	dnf -y remove kexec-tools </dev/null >/dev/null 2>&1 ||
		fail "cannot remove the package kexec-tools"
fi
# Configuration files that the removal saved, unless they were there
# before the lab
for f in /etc/kdump.conf.rpmsave /etc/sysconfig/kdump.rpmsave; do
	[ -e "$f" ] || continue
	grep -qxF "$f" "$STATE/rpmsave" 2>/dev/null || rm -f "$f"
done

# No kernel has a crashkernel argument, and neither have kernels
# installed later. With ALL, grubby also updates GRUB_CMDLINE_LINUX.
grubby --update-kernel=ALL --remove-args=crashkernel >/dev/null 2>&1 ||
	fail "cannot remove the crashkernel argument"
if grep -Eq '^GRUB_CMDLINE_LINUX=.*crashkernel=' /etc/default/grub; then
	sed -Ei '/^GRUB_CMDLINE_LINUX=/ { s/crashkernel=[^ "]*//g; s/  +/ /g; s/=" /="/; s/ "$/"/ }' \
		/etc/default/grub
fi
if grubby --info=ALL 2>/dev/null | grep -q '^args=.*crashkernel='; then
	fail "a kernel still has a crashkernel argument"
fi
