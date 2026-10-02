#!/bin/bash
# mysql-01 setup: give the student a machine without a MySQL or MariaDB
# server, so the lab starts from a fresh installation. Prints nothing on
# success.
#
# A server that was there before the lab (servera keeps mysql-server from
# the replication labs) is not destroyed. The first run records it in
# /var/tmp/mysql-01.pre and puts it aside in /var/tmp/mysql-01.bak: the
# package versions and their RPM files, the data directory, the option
# files, the log directory, root's client files and the service state.
# cleanup.sh puts all of it back.
set -eu

pre=/var/tmp/mysql-01.pre
bak=/var/tmp/mysql-01.bak
servers="mysql-server mariadb-server"
datadir=/var/lib/mysql
# Files and directories restored as they were (only those that exist)
paths="etc/my.cnf etc/my.cnf.d var/log/mysql root/.my.cnf root/.mysql_history"

had() {
	grep -qx "$1" "$pre"
}

# First run only: what the machine looked like before the lab
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	mkdir "$bak/rpms.d"
	tmp_pre="$pre.tmp"
	: > "$tmp_pre"
	for p in $servers; do
		if rpm -q "$p" >/dev/null 2>&1; then
			echo "$p-installed" >> "$tmp_pre"
			echo "$p $(rpm -q "$p")" >> "$bak/rpms"
			# Keep the RPM file, so cleanup can reinstall this exact
			# version even if the repositories have moved on.
			dnf -y reinstall --downloadonly --downloaddir="$bak/rpms.d" \
				"$(rpm -q "$p")" </dev/null >/dev/null 2>&1 || true
		fi
	done
	for u in mysqld mariadb; do
		systemctl is-enabled --quiet "$u" 2>/dev/null && echo "$u-enabled" >> "$tmp_pre"
		systemctl is-active --quiet "$u" 2>/dev/null && echo "$u-active" >> "$tmp_pre"
	done
	systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1 || true

	keep=""
	for p in $paths; do
		[ -e "/$p" ] && keep="$keep $p"
	done
	if [ -n "$keep" ]; then
		# shellcheck disable=SC2086 # word splitting is intended
		tar --selinux --xattrs --acls -C / -cpf "$bak/files.tar" $keep
	fi
	if [ -d "$datadir" ] && [ -n "$(ls -A "$datadir")" ]; then
		mv "$datadir" "$bak/datadir"
		echo "datadir" >> "$tmp_pre"
	fi
	mv "$tmp_pre" "$pre"
fi

systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1 || true

# Remove the server packages. A server that was there before the lab goes
# without its dependencies, so that cleanup only has to put the server
# package back; one the lab installed goes with them.
for p in $servers; do
	rpm -q "$p" >/dev/null 2>&1 || continue
	if had "$p-installed"; then
		dnf -y --setopt=clean_requirements_on_remove=False remove "$p" \
			</dev/null >/dev/null
	else
		dnf -y remove "$p" </dev/null >/dev/null
	fi
done

# Leftovers of the previous server or of an earlier attempt: data,
# option files saved by rpm, root's client files with an old password
if [ -d "$datadir" ]; then
	find "$datadir" -mindepth 1 -delete
fi
rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
rm -f /root/.my.cnf /root/.mysql_history
