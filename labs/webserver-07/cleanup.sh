#!/bin/bash
# webserver-07 cleanup: stop and disable httpd, remove the virtual host,
# /srv/lab-ca, /srv/intranet and the hosts entry, put the firewall, the
# local file context rules for /srv/intranet and the SELinux runtime
# mode back as setup.sh recorded them, and restore the package set
# (pkg_restore). When the lab installed httpd, the files of the apache
# account go before pkg_restore, so the account is removed with the
# package. Afterwards every key, certificate, request and trust anchor
# under /etc/pki/tls and /etc/pki/ca-trust/source that was not there at
# the first start and that no package owns is deleted, and the trust
# store is extracted again. An httpd from before the lab gets its
# service state back. When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=webserver-07
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
CA=/srv/lab-ca
SITE=/srv/intranet
VHOST=/etc/httpd/conf.d/intranet.conf
FC_LOCAL=/etc/selinux/targeted/contexts/files/file_contexts.local
PKI_DIRS="/etc/pki/tls /etc/pki/ca-trust/source"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

fc_rules() {
	[ -r "$FC_LOCAL" ] || return 0
	awk '$1 ~ /^\/srv\/intranet/ { print $1 }' "$FC_LOCAL"
}

pki_list() {
	# shellcheck disable=SC2086 # word splitting is intended
	find $PKI_DIRS -xdev 2>/dev/null | LC_ALL=C sort
}

systemctl disable --now httpd >/dev/null 2>&1
systemctl reset-failed httpd >/dev/null 2>&1
rm -f "$VHOST"
rm -rf "$CA" "$SITE"
sed -i '/intranet\.lab\.example/d' /etc/hosts

if [ -r "$STATE_FILE" ]; then
	# Firewall: https and 443/tcp in the recorded zone as they were
	zone=$(state_value zone)
	fw_open=" $(state_value fw_open) "
	if [ -n "$zone" ] && systemctl is-active --quiet firewalld 2>/dev/null; then
		for s in service:https port:443/tcp; do
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

	# File context rules for /srv/intranet added since the first start,
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

# A new httpd: delete what the apache account owns or what lives in its
# directories, so that pkg_restore can remove the account
httpd_before=yes
if ! pkg_was_installed "$LAB" httpd; then
	httpd_before=no
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

# Keys, certificates, requests and trust anchors added since the first
# start (the default localhost certificate of mod_ssl among them),
# unless a package owns them; then extract the trust store again
if [ -r "$REC_DIR/pki.list" ]; then
	pki_list | LC_ALL=C comm -13 "$REC_DIR/pki.list" - | LC_ALL=C sort -r |
		while IFS= read -r p; do
			rpm -qf "$p" >/dev/null 2>&1 && continue
			if [ -d "$p" ] && [ ! -L "$p" ]; then
				rmdir "$p" 2>/dev/null
			else
				rm -f "$p"
			fi
		done
	update-ca-trust extract || rc=1
fi

# An httpd from before the lab gets its service state back
if rpm -q httpd >/dev/null 2>&1; then
	services=" $(state_value services) "
	case "$services" in
	*" httpd:enabled "*) systemctl enable httpd >/dev/null 2>&1 ;;
	esac
	case "$services" in
	*" httpd:active "*) systemctl start httpd >/dev/null 2>&1 ;;
	esac
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
