#!/bin/bash
# postgres-01 setup: give the student a machine without PostgreSQL, so the
# lab starts from a fresh installation. Prints nothing on success.
#
# A PostgreSQL that was there before the lab (servera keeps one from the
# replication labs) is not destroyed. The first run records it in
# /var/tmp/postgres-01.pre and puts it aside in /var/tmp/postgres-01.bak:
# the postgresql* packages with their versions, install reasons and RPM
# files, the module stream file, the whole /var/lib/pgsql (data directory
# included), whether the user postgres existed and the service state.
# cleanup.sh puts all of it back.
set -eu

STATE_FILE=/opt/linux-labs/state/postgres-01
pre=/var/tmp/postgres-01.pre
bak=/var/tmp/postgres-01.bak
home=/var/lib/pgsql
modfile=/etc/dnf/modules.d/postgresql.module

# First run only: what the machine looked like before the lab
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	mkdir "$bak/rpms.d"
	tmp_pre="$pre.tmp"
	: > "$tmp_pre"
	: > "$bak/rpms"
	for nevra in $(rpm -qa 'postgresql*' | sort); do
		name=$(rpm -q --qf '%{NAME}' "$nevra")
		reason=$(dnf repoquery --installed --qf '%{reason}' "$nevra" \
			</dev/null 2>/dev/null | tail -n 1)
		echo "$name $nevra ${reason:-user}" >> "$bak/rpms"
		# Keep the RPM file, so cleanup can reinstall this exact version
		# even if the repositories have moved on.
		dnf -y reinstall --downloadonly --downloaddir="$bak/rpms.d" \
			"$nevra" </dev/null >/dev/null 2>&1 || true
	done
	[ -f "$modfile" ] && cp -p "$modfile" "$bak/postgresql.module"
	getent passwd postgres >/dev/null && echo "user" >> "$tmp_pre"
	systemctl is-enabled --quiet postgresql 2>/dev/null && echo "enabled" >> "$tmp_pre"
	systemctl is-active --quiet postgresql 2>/dev/null && echo "active" >> "$tmp_pre"
	systemctl disable --now postgresql </dev/null >/dev/null 2>&1 || true
	if [ -e "$home" ]; then
		mv "$home" "$bak/pgsql"
		echo "home" >> "$tmp_pre"
	fi
	mv "$tmp_pre" "$pre"
fi

systemctl disable --now postgresql </dev/null >/dev/null 2>&1 || true

# Remove every postgresql* package. Packages an earlier attempt installed
# go first, with their dependencies. Packages that were there before the
# lab go after them without their dependencies, so that cleanup only has
# to put them back.
recorded() {
	awk -v p="$1" '$1 == p { f = 1 } END { exit !f }' "$bak/rpms"
}
for pass in new old; do
	for nevra in $(rpm -qa 'postgresql*'); do
		# An earlier removal in this loop may have taken it already
		rpm -q "$nevra" >/dev/null 2>&1 || continue
		name=$(rpm -q --qf '%{NAME}' "$nevra")
		if [ "$pass" = new ] && ! recorded "$name"; then
			dnf -y remove "$name" </dev/null >/dev/null
		elif [ "$pass" = old ]; then
			dnf -y --setopt=clean_requirements_on_remove=False \
				remove "$name" </dev/null >/dev/null
		fi
	done
done

# Leftovers of an earlier attempt: data directory, logs, unit drop-ins
rm -rf "$home" /etc/systemd/system/postgresql.service.d
systemctl daemon-reload </dev/null >/dev/null 2>&1 || true

mkdir -p "$(dirname "$STATE_FILE")"
echo "fresh" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
