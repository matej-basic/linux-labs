#!/bin/bash
# selinux-04 cleanup: undo the lab and the solution, leave SELinux
# enforcing. The boolean httpd_enable_homedirs goes back to its recorded
# value, the lab user and the UserDir configuration go, and httpd and the
# SELinux tools go through pkg_restore. An httpd that was there before
# the lab keeps its enabled and running state.
source /opt/linux-labs/lib/packages.sh

LAB=selinux-04
USR=webdev
STATE_FILE=/opt/linux-labs/state/$LAB

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now httpd >/dev/null 2>&1 || true
rm -f /etc/httpd/conf.d/lab-userdir.conf

if id "$USR" >/dev/null 2>&1; then
	pkill -u "$USR" >/dev/null 2>&1 || true
	userdel -r "$USR" >/dev/null 2>&1 || true
fi
rm -rf "/home/${USR:?}" "/var/spool/mail/$USR"

# Policy modules installed at the default priority 400 since the first
# start: audit2allow modules and permissive domains
if [ -r "$STATE_FILE" ] && command -v semodule >/dev/null 2>&1; then
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
fi

# The boolean, before pkg_restore can remove semanage. When there was no
# local boolean customization at the first start and the lab's boolean
# is the only one now, delete the customization; otherwise set the
# recorded persistent value.
if [ -r "$STATE_FILE" ] && command -v getenforce >/dev/null 2>&1 &&
	[ "$(getenforce 2>/dev/null)" != Disabled ]; then
	bool_now=$(state_value bool_now)
	bool_saved=$(state_value bool_saved)
	bool_local=$(state_value bool_local)
	local_now=$(semanage boolean -l -C 2>/dev/null |
		awk 'NR > 1 && NF { print $1 }' | tr '\n' ' ')
	if [ -z "${bool_local// /}" ] &&
		[ "${local_now// /}" = httpd_enable_homedirs ]; then
		semanage boolean -D >/dev/null 2>&1 || true
	fi
	saved_now=$(semanage boolean -l 2>/dev/null |
		awk '$1 == "httpd_enable_homedirs" { gsub(/[(),]/, " "); print $3 }')
	if [ -n "$bool_saved" ] && [ -n "$saved_now" ] &&
		[ "$saved_now" != "$bool_saved" ]; then
		setsebool -P httpd_enable_homedirs "$bool_saved" >/dev/null 2>&1 || true
	fi
	if [ -n "$bool_now" ]; then
		setsebool httpd_enable_homedirs "$bool_now" >/dev/null 2>&1 || true
	fi
fi

httpd_before=yes
if ! pkg_was_installed "$LAB" httpd; then
	httpd_before=no
	# New httpd: delete what the apache account owns, so that
	# pkg_restore can remove the account
	rm -rf /var/log/httpd/* /var/cache/httpd
fi
# setroubleshoot-server, if the student installed it: its account owns
# /var/lib/setroubleshoot and may still run setroubleshootd
if ! pkg_was_installed "$LAB" setroubleshoot-server; then
	pkill -u setroubleshoot >/dev/null 2>&1 || true
	rm -rf /var/lib/setroubleshoot
fi

rc=0
pkg_restore "$LAB" || rc=1

# Empty directories rpm leaves behind after removing a new httpd
if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	rmdir /etc/httpd/conf.d /etc/httpd/conf.modules.d /etc/httpd \
		2>/dev/null || true
fi

# An httpd from before the lab gets its service state back
if [ "$httpd_before" = yes ] && rpm -q httpd >/dev/null 2>&1; then
	if [ "$(state_value httpd_was_enabled)" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	fi
	if [ "$(state_value httpd_was_active)" = yes ]; then
		systemctl start httpd >/dev/null 2>&1 || true
	fi
fi

if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = Permissive ]; then
	setenforce 1 || true
fi

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
