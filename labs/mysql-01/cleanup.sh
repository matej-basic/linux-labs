#!/bin/bash
# mysql-01 cleanup: remove the MySQL server the lab installed and put back
# what setup.sh recorded in /var/tmp/mysql-01.pre and
# /var/tmp/mysql-01.bak: the server packages in their old versions, the
# data directory, the option files, the log directory, root's client
# files and the service state.

pre=/var/tmp/mysql-01.pre
bak=/var/tmp/mysql-01.bak
servers="mysql-server mariadb-server"
datadir=/var/lib/mysql
paths="etc/my.cnf etc/my.cnf.d var/log/mysql root/.my.cnf root/.mysql_history"

# setup.sh never ran: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# want <pkg>: the recorded name-version-release.arch, or nothing
want() {
	[ -f "$bak/rpms" ] || return 0
	awk -v p="$1" '$1 == p { print $2 }' "$bak/rpms"
}

systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1

# Server packages: remove every one that is not exactly the recorded
# version (the dependencies of one the lab installed go with it), then
# install the recorded versions, from the saved RPM file when there is one
install=""
for p in $servers; do
	w=$(want "$p")
	if rpm -q "$p" >/dev/null 2>&1; then
		[ -n "$w" ] && [ "$(rpm -q "$p")" = "$w" ] && continue
		if [ -n "$w" ]; then
			dnf -y --setopt=clean_requirements_on_remove=False remove "$p" \
				</dev/null >/dev/null 2>&1
		else
			dnf -y remove "$p" </dev/null >/dev/null 2>&1
		fi
	fi
	if [ -n "$w" ]; then
		if [ -f "$bak/rpms.d/$w.rpm" ]; then
			install="$install $bak/rpms.d/$w.rpm"
		else
			install="$install $w"
		fi
	fi
done
if [ -n "$install" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y install $install </dev/null >/dev/null 2>&1 || {
		echo "Cannot reinstall$install" >&2
		exit 1
	}
fi

# Data directory: the recorded one, else empty or gone
if [ -d "$datadir" ]; then
	find "$datadir" -mindepth 1 -delete 2>/dev/null
fi
if had datadir && [ -d "$bak/datadir" ]; then
	rm -rf "$datadir"
	mv "$bak/datadir" "$datadir" || exit 1
	restorecon -R "$datadir" 2>/dev/null
elif [ -d "$datadir" ] && ! rpm -qf "$datadir" >/dev/null 2>&1; then
	rmdir "$datadir" 2>/dev/null
fi

# Option files, log directory and root's client files as they were
for p in $paths; do
	[ -e "/$p" ] || continue
	rpm -qf "/$p" >/dev/null 2>&1 && [ ! -f "$bak/files.tar" ] && continue
	rm -rf "/${p:?}"
done
rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
if [ -f "$bak/files.tar" ]; then
	tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar" || exit 1
	for p in $paths; do
		[ -e "/$p" ] && restorecon -R "/$p" 2>/dev/null
	done
fi

for u in mysqld mariadb; do
	systemctl cat "$u" </dev/null >/dev/null 2>&1 || continue
	had "$u-enabled" && systemctl enable "$u" </dev/null >/dev/null 2>&1
	had "$u-active" && systemctl start "$u" </dev/null >/dev/null 2>&1
done

rm -rf "$pre" "$bak"
exit 0
