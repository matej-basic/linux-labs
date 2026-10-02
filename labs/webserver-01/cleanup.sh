#!/bin/bash
# webserver-01 cleanup: remove httpd if the lab installed it; otherwise
# put back what setup.sh recorded: the service state, /etc/httpd,
# /var/www/html and the firewall services and ports.
STATE_FILE=/opt/linux-labs/state/webserver-01
bak=/var/tmp/webserver-01.bak

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

if [ ! -r "$STATE_FILE" ]; then
	# Lab was not started through labctl: stop what a solution started
	systemctl disable --now httpd >/dev/null 2>&1 || true
	exit 0
fi

systemctl stop httpd >/dev/null 2>&1 || true

if [ "$(state_value httpd_preinstalled)" = yes ]; then
	if [ -f "$bak/files.tar" ]; then
		# Delete files the lab added, then restore the recorded ones
		tar -tf "$bak/files.tar" | sed 's|/$||' | sort > "$bak/list"
		while read -r f; do
			f=${f#/}
			grep -qxF "$f" "$bak/list" || rm -f "/$f"
		done < <(find /etc/httpd /var/www/html \( -type f -o -type l \) 2>/dev/null)
		tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar"
	fi
	if [ "$(state_value httpd_enabled)" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	else
		systemctl disable httpd >/dev/null 2>&1 || true
	fi
	if [ "$(state_value httpd_active)" = yes ]; then
		systemctl restart httpd >/dev/null 2>&1 || true
	fi
else
	systemctl disable --now httpd >/dev/null 2>&1 || true
	if rpm -q httpd >/dev/null 2>&1; then
		dnf -y remove httpd >/dev/null 2>&1 || true
	fi
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
	fw_restore service "$(state_value fw_services)"
	fw_restore port "$(state_value fw_ports)"
fi

rm -rf "$bak"
rm -f "$STATE_FILE"
exit 0
