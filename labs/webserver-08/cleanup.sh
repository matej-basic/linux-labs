#!/bin/bash
# webserver-08 cleanup: stop and disable httpd, delete every path under
# /etc/httpd and /var/www that is new since the first start and that no
# package owns (the content, the htpasswd file, the student's
# configuration), put the firewall and the SELinux runtime mode back as
# setup.sh recorded them, and restore the package set (pkg_restore).
# When the lab installed httpd, the files of the apache account go
# before pkg_restore, so the account is removed with the package, and
# the directories rpm leaves behind go afterwards. Trees that existed at
# the first start come back from the recorded copy, and an httpd from
# before the lab gets its service state back. When the package set
# cannot be restored, the records stay for the next reset and the exit
# status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=webserver-08
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
TREES="/etc/httpd /var/www"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

tree_list() {
	# shellcheck disable=SC2086 # word splitting is intended
	find $TREES -xdev 2>/dev/null | LC_ALL=C sort
}

# Paths under the trees that are new since the first start and that no
# package owns
remove_new_paths() {
	[ -r "$REC_DIR/files.list" ] || return 0
	tree_list | LC_ALL=C comm -13 "$REC_DIR/files.list" - | LC_ALL=C sort -r |
		while IFS= read -r p; do
			rpm -qf "$p" >/dev/null 2>&1 && continue
			if [ -d "$p" ] && [ ! -L "$p" ]; then
				rmdir "$p" 2>/dev/null
			else
				rm -f "$p"
			fi
		done
	return 0
}

# Was the path there at the first start
recorded() {
	[ -r "$REC_DIR/files.list" ] && grep -qxF "$1" "$REC_DIR/files.list"
}

systemctl disable --now httpd >/dev/null 2>&1
systemctl reset-failed httpd >/dev/null 2>&1
remove_new_paths

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
	# shellcheck disable=SC2086 # word splitting is intended
	find $TREES -xdev \( -user apache -o -group apache \) -delete 2>/dev/null
fi

rc=0
pkg_restore "$LAB" || rc=1

# Directories that rpm left behind after removing a new httpd, and the
# content tree when httpd was never installed, unless they were there
# at the first start or a package still owns them
if [ "$httpd_before" = no ] && [ -r "$STATE_FILE" ] && ! rpm -q httpd >/dev/null 2>&1; then
	for p in /etc/httpd /var/log/httpd /var/www; do
		recorded "$p" && continue
		if [ -e "$p" ] && ! rpm -qf "$p" >/dev/null 2>&1; then
			rm -rf "${p:?}"
		fi
	done
fi

# Trees that existed at the first start: delete what is new, then put
# back the recorded files, which also undoes edits of packaged files
if [ -f "$REC_DIR/files.tar" ]; then
	remove_new_paths
	tar --selinux --xattrs --acls -C / -xpf "$REC_DIR/files.tar" || rc=1
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
