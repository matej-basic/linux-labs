#!/bin/bash
# logging-07 grader
source /opt/linux-labs/lib/grading.sh

STATE_DIR=/opt/linux-labs/state/logging-07
CONF=/etc/aide.conf
DB=/var/lib/aide/aide.db.gz
APP=/srv/app
REPORT=/root/aide-report.txt

grade_begin logging-07
grade_require_state logging-07 "$STATE_DIR/started"

started=$(cat "$STATE_DIR/started")
tampered=$(cat "$STATE_DIR/tampered" 2>/dev/null)
added=$(cat "$STATE_DIR/added" 2>/dev/null)
added=${added:-$APP/bin/.appctl-helper}

T=$(mktemp -d /tmp/logging-07-grade.XXXXXX)
trap 'rm -rf "$T"' EXIT

# A selection line of an AIDE configuration: a path regex after an
# optional !, = or (AIDE 0.19) -.
SEL_RE='^[[:space:]]*[-!=]?/'

# make_conf <db_in> <db_out> <out> [fixture root]: a copy of the
# student's configuration that reads <db_in>, writes an uncompressed
# <db_out> and reports to stdout only. With a fixture root, only the
# selection lines that name /srv/app stay, moved below that root.
make_conf() {
	local in=$1 out=$2 dst=$3 root=${4:-}
	sed -E \
		-e "s#^([[:space:]]*(database|database_in)[[:space:]]*=).*#\\1file:$in#" \
		-e '/^[[:space:]]*(database_out|gzip_dbout|report_url)[[:space:]]*=/d' \
		"$CONF" > "$dst" || return 1
	if [ -n "$root" ]; then
		awk -v re="$SEL_RE" -v root="$root" '
			$0 ~ re {
				if (index($0, "/srv/app") == 0) next
				gsub("/srv/app", root "/srv/app")
			}
			{ print }' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst" ||
			return 1
	fi
	printf 'database_out=file:%s\ngzip_dbout=no\nreport_url=stdout\n' \
		"$out" >> "$dst"
}

# entries <report> <section>: the paths of one section (Added, Removed
# or Changed) of an AIDE report
entries() {
	awk -v want="$2 entries:" '
		/^[A-Z][a-z]+ entries:$/ { sec = $0; next }
		/^Detailed information/ || /^The attributes of/ { sec = "" }
		sec == want && /^[^ ].*: \// { sub(/^[^:]*: /, ""); print }
	' "$1"
}

# gen_time <db>: the generation time of an AIDE database (epoch), from
# its header line, else the file's mtime
gen_time() {
	local g
	g=$(zcat -f "$1" 2>/dev/null | head -n 5 |
		sed -n 's/^# Time of generation was //p')
	if [ -n "$g" ]; then
		date -d "$g" +%s 2>/dev/null
	else
		stat -c %Y "$1" 2>/dev/null
	fi
}

# A database of the current configuration, written by the grader.
fresh=1
if rpm -q aide >/dev/null 2>&1 && [ -f "$CONF" ] &&
	make_conf "$T/none.db" "$T/fresh.db" "$T/fresh.conf" &&
	timeout 90 aide -c "$T/fresh.conf" --init >/dev/null 2>&1 &&
	[ -f "$T/fresh.db" ]; then
	sed -n 's/^\(\/[^ ]*\) .*/\1/p' "$T/fresh.db" > "$T/fresh.list"
	fresh=0
fi

only_srv_app() {
	[ "$fresh" = 0 ] || return 1
	grep -qxF "$APP/etc/app.conf" "$T/fresh.list" || return 1
	grep -qxF "$APP/bin/appctl" "$T/fresh.list" || return 1
	! grep -qvE "^$APP(/|\$)" "$T/fresh.list"
}

data_excluded() {
	[ "$fresh" = 0 ] || return 1
	grep -qxF "$APP/etc/app.conf" "$T/fresh.list" || return 1
	! grep -qE "^$APP/data/" "$T/fresh.list"
}

# The /srv/app rules, applied to a copy of the tree below a scratch
# directory: a change of content, permissions, owner or group of a file
# is reported.
rule_attributes() {
	local f rc root=$T/fixture
	rpm -q aide >/dev/null 2>&1 && [ -f "$CONF" ] || return 1
	mkdir -p "$root/srv" && cp -a "$APP" "$root/srv/" 2>/dev/null ||
		return 1
	rm -f "$root$added"
	for f in content perms owner group; do
		printf 'fixture %s\n' "$f" > "$root/srv/app/etc/$f.conf"
	done
	chown root:root "$root/srv/app/etc/"*.conf
	chmod 644 "$root/srv/app/etc/"*.conf
	make_conf "$T/fixture.db" "$T/fixture.db" "$T/fixture.conf" \
		"$root" || return 1
	timeout 90 aide -c "$T/fixture.conf" --init >/dev/null 2>&1 ||
		return 1
	echo changed >> "$root/srv/app/etc/content.conf"
	chmod 600 "$root/srv/app/etc/perms.conf"
	chown 65534 "$root/srv/app/etc/owner.conf"
	chgrp 65534 "$root/srv/app/etc/group.conf"
	timeout 90 aide -c "$T/fixture.conf" --check > "$T/fixture.out" 2>&1
	rc=$?
	[ $((rc & 4)) -ne 0 ] || return 1
	entries "$T/fixture.out" Changed > "$T/fixture.changed"
	for f in content perms owner group; do
		grep -qxF "$root/srv/app/etc/$f.conf" "$T/fixture.changed" ||
			return 1
	done
}

db_before_tamper() {
	local g
	[ -f "$DB" ] && [ -n "$tampered" ] || return 1
	g=$(gen_time "$DB")
	[ -n "$g" ] && [ "$g" -ge "$started" ] && [ "$g" -le "$tampered" ]
}

db_covers_app() {
	[ -f "$DB" ] || return 1
	zcat -f "$DB" 2>/dev/null | grep -q "^$APP/etc/app.conf "
}

report_has() {
	[ -s "$REPORT" ] || return 1
	entries "$REPORT" "$1" | grep -qxF "$2"
}

report_no_data() {
	[ -s "$REPORT" ] || return 1
	grep -q "^AIDE found differences" "$REPORT" || return 1
	! grep -q ": $APP/data/" "$REPORT"
}

# A check by the grader with the student's configuration and database
# finds exactly the changes lab-tamper made to /srv/app.
check_exact() {
	local rc
	[ -f "$DB" ] && [ -n "$tampered" ] || return 1
	make_conf "$DB" "$T/check.db" "$T/check.conf" || return 1
	timeout 90 aide -c "$T/check.conf" --check > "$T/check.out" 2>&1
	rc=$?
	[ "$rc" -eq 5 ] || return 1
	[ "$(entries "$T/check.out" Added)" = "$added" ] || return 1
	[ -z "$(entries "$T/check.out" Removed)" ] || return 1
	[ "$(entries "$T/check.out" Changed | sort | tr '\n' ' ')" = \
		"$APP/bin/appctl $APP/etc/app.conf " ]
}

criterion "Package aide is installed" rpm -q aide
criterion "$CONF passes the AIDE configuration check" \
	timeout 90 aide -c "$CONF" --config-check
criterion "AIDE monitors $APP and nothing outside it" only_srv_app
criterion "Files below $APP/data are excluded" data_excluded
criterion "The $APP rule checks content, permissions, owner and group" \
	rule_attributes
criterion "lab-tamper has run" test -n "$tampered"
criterion "Database $DB covers $APP" db_covers_app
criterion "$DB was initialised before lab-tamper ran" db_before_tamper
criterion "$REPORT lists $APP/etc/app.conf as changed" \
	report_has Changed "$APP/etc/app.conf"
criterion "$REPORT lists $APP/bin/appctl as changed" \
	report_has Changed "$APP/bin/appctl"
criterion "$REPORT lists $added as added" report_has Added "$added"
criterion "$REPORT names nothing below $APP/data" report_no_data
criterion "A new check finds exactly the changes of lab-tamper" check_exact
grade_end
