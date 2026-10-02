#!/bin/bash
# webserver-01 cleanup: stop httpd and restore the package set of the
# first start (pkg_restore): httpd and its dependencies go if the lab
# installed them, and come back if httpd was installed before. Then put
# back what setup.sh recorded: /etc/httpd, /var/www and /var/log/httpd of
# a httpd that was there before, its service state, and the firewall
# services and ports. When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/webserver-01
bak=/var/tmp/webserver-01.bak
dirs="etc/httpd var/www var/log/httpd"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# fw_restore <kind> <recorded list>: kind is service or port
fw_restore() {
	local kind=$1 want=$2 have x
	have=$(firewall-cmd --permanent "--list-${kind}s" 2>/dev/null)
	for x in $have; do
		case " $want " in
		*" $x "*) ;;
		*)
			firewall-cmd --permanent "--remove-$kind=$x" >/dev/null 2>&1 || true
			firewall-cmd "--remove-$kind=$x" >/dev/null 2>&1 || true
			;;
		esac
	done
	for x in $want; do
		case " $have " in
		*" $x "*) ;;
		*)
			firewall-cmd --permanent "--add-$kind=$x" >/dev/null 2>&1 || true
			firewall-cmd "--add-$kind=$x" >/dev/null 2>&1 || true
			;;
		esac
	done
}

systemctl disable --now httpd >/dev/null 2>&1 || true

rc=0
pkg_restore webserver-01 || rc=1

if [ "$(state_value httpd_preinstalled)" = yes ]; then
	if [ -f "$bak/files.tar" ]; then
		# Delete files the lab added, then restore the recorded ones
		tar -tf "$bak/files.tar" | sed 's|/$||' | sort > "$bak/list"
		for p in $dirs; do
			[ -d "/$p" ] || continue
			find "/$p" \( -type f -o -type l \) 2>/dev/null
		done | while read -r f; do
			f=${f#/}
			grep -qxF "$f" "$bak/list" || rm -f "/$f"
		done
		tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar"
	fi
	if [ "$(state_value httpd_enabled)" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	fi
	if [ "$(state_value httpd_active)" = yes ]; then
		systemctl restart httpd >/dev/null 2>&1 || true
	fi
elif [ -r "$STATE_FILE" ]; then
	# httpd is gone again: its configuration, content and logs too,
	# unless another package still owns the directory
	for p in $dirs; do
		if [ -d "/$p" ] && ! rpm -qf "/$p" >/dev/null 2>&1; then
			rm -rf "/${p:?}"
		fi
	done
fi

if [ -r "$STATE_FILE" ] && command -v firewall-cmd >/dev/null 2>&1 \
	&& systemctl is-active --quiet firewalld 2>/dev/null; then
	fw_restore service "$(state_value fw_services)"
	fw_restore port "$(state_value fw_ports)"
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$bak"
	rm -f "$STATE_FILE"
fi
exit "$rc"
