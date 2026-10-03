#!/bin/bash
# webserver-04 cleanup: stop nginx and the backend application, remove
# the backend, the certificate, the nginx configuration and the firewall
# openings the lab made, put the SELinux boolean and port labels back as
# setup.sh recorded them and restore the package set of the first start
# (pkg_restore). When the lab installed nginx, its configuration, logs
# and cache go before pkg_restore, so the nginx system user owns no
# files and is removed with the package. An nginx that was there before
# the lab gets its files and service state back afterwards. When the
# package set cannot be restored, the records stay for the next reset
# and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=webserver-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
APP_DIR=/srv/webapp
UNIT=/etc/systemd/system/webapp.service
CRT=/etc/pki/tls/certs/app.lab.local.crt
KEY=/etc/pki/tls/private/app.lab.local.key
BOOL=httpd_can_network_connect
SEL=/var/lib/selinux/targeted/active
paths="etc/nginx var/log/nginx var/lib/nginx var/cache/nginx"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

bool_saved() {
	semanage boolean -l 2>/dev/null |
		awk -v b="$BOOL" '$1 == b { gsub(/[(),]/, " "); print $3 }'
}

systemctl disable --now nginx >/dev/null 2>&1
systemctl disable --now webapp >/dev/null 2>&1
rm -f "$UNIT"
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed webapp >/dev/null 2>&1
rm -rf "$APP_DIR"
rm -f "$CRT" "$KEY" /run/nginx.pid
sed -i '/app\.lab\.local/d' /etc/hosts

if [ -r "$STATE_FILE" ]; then
	# Firewall: close what was not open at the first start
	zone=$(state_value zone)
	fw_open=" $(state_value fw_open) "
	if [ -n "$zone" ] && systemctl is-active --quiet firewalld 2>/dev/null; then
		for s in service:http service:https port:80/tcp port:443/tcp; do
			kind=${s%%:*}
			val=${s#*:}
			case "$fw_open" in
			*" p:$s "*) ;;
			*) firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 ;;
			esac
			case "$fw_open" in
			*" r:$s "*) ;;
			*) firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 ;;
			esac
		done
	fi

	# SELinux, before pkg_restore can remove semanage: a port label
	# for 8081 that is new goes, the boolean gets its recorded values.
	# When nothing was customized at the first start and the lab's
	# boolean is the only local customization now, it is deleted.
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
		if [ "$(state_value port_local)" = no ]; then
			t=$(semanage port -l -C 2>/dev/null |
				awk '$2 == "tcp" && /[[:space:],]8081(,|[[:space:]]|$)/ { print $1; exit }')
			if [ -n "$t" ]; then
				semanage port -d -t "$t" -p tcp 8081 >/dev/null 2>&1
			fi
		fi
		if [ "$(state_value bool_local)" = no ] && [ "$(state_value bools_local)" = no ] &&
			[ "$(grep '^[^#]' "$SEL/booleans.local" 2>/dev/null | cut -d= -f1)" = "$BOOL" ]; then
			semanage boolean -D >/dev/null 2>&1
		fi
		want=$(state_value bool_saved)
		now=$(bool_saved)
		if [ -n "$want" ] && [ -n "$now" ] && [ "$now" != "$want" ]; then
			setsebool -P "$BOOL" "$want" >/dev/null 2>&1
		fi
		want=$(state_value bool_now)
		[ -n "$want" ] && setsebool "$BOOL" "$want" >/dev/null 2>&1
	fi
fi

# No nginx before the lab: its configuration, logs and cache go before
# pkg_restore, so the nginx user and group own nothing and can be
# removed. An nginx from before the lab is restored from the backup.
if [ -r "$STATE_FILE" ] && [ "$(state_value nginx_pre)" = no ]; then
	for p in $paths; do
		rm -rf "/${p:?}"
	done
fi

rc=0
pkg_restore "$LAB" || rc=1

# Directories that rpm left behind and that no package owns any more
if [ -r "$STATE_FILE" ] && [ "$(state_value nginx_pre)" = no ]; then
	for p in $paths usr/share/nginx; do
		if [ -e "/$p" ] && ! rpm -qf "/$p" >/dev/null 2>&1; then
			rm -rf "/${p:?}"
		fi
	done
fi

# nginx was installed before the lab: pkg_restore installed it again
if [ -d "$BACKUP_DIR" ] && rpm -q nginx >/dev/null 2>&1; then
	systemctl stop nginx >/dev/null 2>&1
	if [ -f "$BACKUP_DIR/files.tar" ]; then
		for p in $paths; do
			rm -rf "/${p:?}"
		done
		tar --selinux --xattrs --acls -C / -xpf "$BACKUP_DIR/files.tar" || rc=1
		for p in $paths; do
			[ -e "/$p" ] && restorecon -R "/$p" >/dev/null 2>&1
		done
	fi
	[ -f "$BACKUP_DIR/enabled" ] && systemctl enable nginx >/dev/null 2>&1
	[ -f "$BACKUP_DIR/active" ] && systemctl start nginx >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$BACKUP_DIR"
	rm -f "$STATE_FILE"
fi
exit "$rc"
