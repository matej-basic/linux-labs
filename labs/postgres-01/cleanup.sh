#!/bin/bash
# postgres-01 cleanup: remove the PostgreSQL the lab installed and put
# back what setup.sh recorded in /var/tmp/postgres-01.pre and
# /var/tmp/postgres-01.bak: the postgresql* packages in their old
# versions and install reasons, the module stream file, /var/lib/pgsql,
# the user postgres and the service state.

STATE_FILE=/opt/linux-labs/state/postgres-01
pre=/var/tmp/postgres-01.pre
bak=/var/tmp/postgres-01.bak
home=/var/lib/pgsql
modfile=/etc/dnf/modules.d/postgresql.module

rm -f "$STATE_FILE"

# setup.sh never ran: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# want <name>: the recorded name-version-release.arch, or nothing
want() {
	[ -f "$bak/rpms" ] || return 0
	awk -v p="$1" '$1 == p { print $2 }' "$bak/rpms"
}

systemctl disable --now postgresql </dev/null >/dev/null 2>&1
rm -rf /etc/systemd/system/postgresql.service.d
systemctl daemon-reload </dev/null >/dev/null 2>&1

# Packages: remove every postgresql* package that is not exactly the
# recorded version. Packages the lab installed go first, with their
# dependencies; then the recorded ones in another version, without them.
for pass in new old; do
	for nevra in $(rpm -qa 'postgresql*'); do
		rpm -q "$nevra" >/dev/null 2>&1 || continue
		name=$(rpm -q --qf '%{NAME}' "$nevra")
		w=$(want "$name")
		if [ "$pass" = new ] && [ -z "$w" ]; then
			dnf -y remove "$name" </dev/null >/dev/null 2>&1
		elif [ "$pass" = old ] && [ -n "$w" ] && [ "$nevra" != "$w" ]; then
			dnf -y --setopt=clean_requirements_on_remove=False \
				remove "$name" </dev/null >/dev/null 2>&1
		fi
	done
done

# Module stream state as it was, before the old packages come back
if [ -f "$bak/postgresql.module" ]; then
	cp -p "$bak/postgresql.module" "$modfile"
else
	rm -f "$modfile"
fi

# Then install the recorded versions, from the saved RPM file when there
# is one, and give them their old install reason
install=""
if [ -f "$bak/rpms" ]; then
	while read -r name nevra reason; do
		rpm -q "$nevra" >/dev/null 2>&1 && continue
		if [ -f "$bak/rpms.d/$nevra.rpm" ]; then
			install="$install $bak/rpms.d/$nevra.rpm"
		else
			install="$install $nevra"
		fi
	done < "$bak/rpms"
fi
if [ -n "$install" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y install $install </dev/null >/dev/null 2>&1 || {
		echo "Cannot reinstall$install" >&2
		exit 1
	}
fi
if [ -f "$bak/rpms" ]; then
	while read -r name nevra reason; do
		[ "$reason" = dependency ] || continue
		dnf -y mark remove "$name" </dev/null >/dev/null 2>&1
	done < "$bak/rpms"
fi

# /var/lib/pgsql as it was (data directory included), else gone
rm -rf "$home"
if had home && [ -d "$bak/pgsql" ]; then
	mv "$bak/pgsql" "$home" || exit 1
fi

# The user postgres only if it existed before the lab
if ! had user && getent passwd postgres >/dev/null; then
	userdel postgres >/dev/null 2>&1
	getent group postgres >/dev/null && groupdel postgres >/dev/null 2>&1
fi

systemctl daemon-reload </dev/null >/dev/null 2>&1
if systemctl cat postgresql </dev/null >/dev/null 2>&1; then
	had enabled && systemctl enable postgresql </dev/null >/dev/null 2>&1
	had active && systemctl start postgresql </dev/null >/dev/null 2>&1
fi

rm -rf "$pre" "$bak"
exit 0
