#!/bin/bash
# webserver-06 cleanup: stop and disable httpd and php-fpm, remove the
# pool, the Apache configuration, /srv/phpapp and the user phpapp, put
# the firewall, the local file context rules for /srv/phpapp and the
# SELinux runtime mode back as setup.sh recorded them, and restore the
# package set (pkg_restore). When the lab installed httpd or php-fpm,
# the files of the apache account go before pkg_restore, so the account
# is removed with the packages. An httpd or php-fpm from before the lab
# gets its service state back. When the package set cannot be restored,
# the records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=webserver-06
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
APP=/srv/phpapp
POOL=/etc/php-fpm.d/intranet.conf
VHOST=/etc/httpd/conf.d/phpapp.conf
FC_LOCAL=/etc/selinux/targeted/contexts/files/file_contexts.local

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

fc_rules() {
	[ -r "$FC_LOCAL" ] || return 0
	awk '$1 ~ /^\/srv\/phpapp/ { print $1 }' "$FC_LOCAL"
}

systemctl disable --now httpd php-fpm >/dev/null 2>&1
systemctl reset-failed httpd php-fpm >/dev/null 2>&1
rm -f "$POOL" "$VHOST"
rm -rf "$APP"
if id phpapp >/dev/null 2>&1; then
	pkill -KILL -u phpapp >/dev/null 2>&1
	userdel phpapp >/dev/null 2>&1
fi

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

	# File context rules for /srv/phpapp added since the first start,
	# before pkg_restore can remove semanage
	if command -v semanage >/dev/null 2>&1; then
		before=" $(state_value fc_rules) "
		for p in $(fc_rules); do
			case "$before" in
			*" $p "*) ;;
			*) semanage fcontext -d "$p" >/dev/null 2>&1 ;;
			esac
		done
	fi
	if [ "$(state_value selinux_mode)" = Permissive ]; then
		setenforce 0 >/dev/null 2>&1
	fi
fi

# New packages: delete what the apache account owns or what lives in
# its directories, so that pkg_restore can remove the account
httpd_before=yes
fpm_before=yes
if ! pkg_was_installed "$LAB" httpd; then
	httpd_before=no
	rm -rf /var/log/httpd/* /var/cache/httpd
fi
if ! pkg_was_installed "$LAB" php-fpm; then
	fpm_before=no
	rm -rf /var/log/php-fpm/* /var/lib/php/session/* \
		/var/lib/php/wsdlcache/* /var/lib/php/opcache/*
fi

rc=0
pkg_restore "$LAB" || rc=1

# Directories that rpm left behind after removing a new package
if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	for p in /etc/httpd /var/log/httpd /var/www; do
		if [ -e "$p" ] && ! rpm -qf "$p" >/dev/null 2>&1; then
			rm -rf "${p:?}"
		fi
	done
fi
if [ "$fpm_before" = no ] && ! rpm -q php-fpm >/dev/null 2>&1; then
	for p in /etc/php-fpm.d /var/log/php-fpm /var/lib/php; do
		if [ -e "$p" ] && ! rpm -qf "$p" >/dev/null 2>&1; then
			rm -rf "${p:?}"
		fi
	done
fi

# A service from before the lab gets its state back
services=" $(state_value services) "
for s in httpd php-fpm; do
	rpm -q "$s" >/dev/null 2>&1 || continue
	case "$services" in
	*" $s:enabled "*) systemctl enable "$s" >/dev/null 2>&1 ;;
	esac
	case "$services" in
	*" $s:active "*) systemctl start "$s" >/dev/null 2>&1 ;;
	esac
done

if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
