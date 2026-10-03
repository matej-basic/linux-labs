#!/bin/bash
# webserver-05 cleanup: stop and disable httpd, remove the site and the
# lab's Apache files, put the firewall, the local SELinux customizations
# (file context and port rules, booleans), the policy modules and the
# SELinux mode back as setup.sh recorded them at the first start, and
# restore the package set (pkg_restore). When the lab installed httpd,
# the files of the apache account go before pkg_restore, so the account
# is removed with the package. An httpd from before the lab gets its
# service state back. When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=webserver-05
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
SITE=/srv/intranet
BUILD=/root/intranet
VHOST=/etc/httpd/conf.d/intranet.conf
STATUS=/etc/httpd/conf.d/status.conf

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# The same as in setup.sh: local SELinux customizations back to the
# recorded state, new policy modules at priority 400 removed
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	command -v semanage >/dev/null 2>&1 || return 0
	now=$(semanage export 2>/dev/null) || return 0
	printf '%s\n' "$now" | grep -E '^(fcontext|port) -a ' |
		grep -vxF -f "$rec" | sed 's/^\([a-z]*\) -a /\1 -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	grep -E '^(fcontext|port) -a ' "$rec" |
		grep -vxF -f <(printf '%s\n' "$now") |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	if [ "$(printf '%s\n' "$now" | grep '^boolean -m ' | sort)" != \
		"$(grep '^boolean -m ' "$rec" | sort)" ]; then
		semanage boolean -D >/dev/null 2>&1 || true
		grep '^boolean -m ' "$rec" | while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	fi
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r m; do
			line=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$line" ] && setsebool "$m" "$line" >/dev/null 2>&1
			true
		done
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

systemctl disable --now httpd >/dev/null 2>&1
systemctl reset-failed httpd >/dev/null 2>&1
rm -f "$VHOST" "$STATUS"
rm -rf "$SITE" "$BUILD"

if [ -r "$STATE_FILE" ]; then
	# Firewall: http and 80/tcp in the recorded zone as they were
	zone=$(state_value zone)
	fw_open=" $(state_value fw_open) "
	if [ -n "$zone" ] && systemctl is-active --quiet firewalld 2>/dev/null; then
		for s in service:http port:80/tcp; do
			kind=${s%%:*}
			val=${s#*:}
			case "$fw_open" in
			*" p:$s "*) firewall-cmd --permanent --zone="$zone" "--add-$kind=$val" >/dev/null 2>&1 ;;
			*) firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 ;;
			esac
			case "$fw_open" in
			*" r:$s "*) firewall-cmd --zone="$zone" "--add-$kind=$val" >/dev/null 2>&1 ;;
			*) firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 ;;
			esac
		done
	fi

	# SELinux, before pkg_restore can remove semanage
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
		selinux_restore
		setenforce 1 >/dev/null 2>&1
		cfg=$(state_value selinux_cfg)
		if [ -n "$cfg" ]; then
			sed -i "s/^SELINUX=.*/SELINUX=$cfg/" /etc/selinux/config
		fi
	fi
fi

httpd_before=yes
if ! pkg_was_installed "$LAB" httpd; then
	httpd_before=no
	# New httpd: delete what the apache account owns, so that
	# pkg_restore can remove the account
	rm -rf /var/log/httpd/* /var/cache/httpd
fi

rc=0
pkg_restore "$LAB" || rc=1

# Directories that rpm left behind after removing a new httpd
if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	for p in /etc/httpd /var/log/httpd /var/www; do
		if [ -e "$p" ] && ! rpm -qf "$p" >/dev/null 2>&1; then
			rm -rf "${p:?}"
		fi
	done
fi

# An httpd from before the lab gets its service state back
if [ "$httpd_before" = yes ] && rpm -q httpd >/dev/null 2>&1; then
	[ "$(state_value httpd_was_enabled)" = yes ] &&
		systemctl enable httpd >/dev/null 2>&1
	[ "$(state_value httpd_was_active)" = yes ] &&
		systemctl start httpd >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
