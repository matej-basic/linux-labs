#!/bin/bash
# postgres-04 setup: a PostgreSQL server that does not start. A fresh
# cluster in /var/lib/pgsql/data gets the database labdb with the table
# inventory (12 rows) and the role labapp, which may read it over TCP
# with a password. Then several faults are added at the same time:
#   - the data directory has mode 0755, which PostgreSQL refuses
#   - postgresql.conf sets port 5433, which has no SELinux port type,
#     so the bind is denied
#   - the pg_hba.conf line for labapp has an invalid authentication
#     method (scram-sha256), so pg_hba.conf cannot be loaded
#   - postgresql is disabled (setup tries to start it once, so the
#     failure is in the journal)
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the service
# state, the SELinux mode in /etc/selinux/config, the policy modules,
# the SELinux booleans and the local SELinux customizations (semanage
# export), and puts an existing /var/lib/pgsql aside in
# /var/tmp/postgres-04.bak. cleanup.sh puts all of it back. Every run
# writes the checksum of the table data to the state file.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=postgres-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
bak=/var/tmp/$LAB.bak
home=/var/lib/pgsql
DATA=$home/data
PASSWORD=Stock-2026

die() {
	echo "Error: $*" >&2
	exit 1
}

# Run a command silently (stdout and stderr); show its output only on
# failure
quiet() {
	local out
	out=$("$@" 2>&1 </dev/null) || { printf '%s\n' "$out" >&2; return 1; }
}

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	die "SELinux is disabled; this lab needs SELinux enabled."
fi

pkg_snapshot "$LAB" || die "cannot record the package set."

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	if [ -e "$bak/pgsql" ]; then
		die "$bak holds a saved $home but no state file exists." \
			"Move it away and start again."
	fi
	rm -rf "$REC_DIR" "$bak"
	mkdir -p "$STATE_DIR"
	mkdir -m 0755 "$REC_DIR"
	mkdir -m 0700 "$bak"
	was_enabled=no
	was_active=no
	systemctl is-enabled --quiet postgresql 2>/dev/null && was_enabled=yes
	systemctl is-active --quiet postgresql 2>/dev/null && was_active=yes
	systemctl disable --now postgresql >/dev/null 2>&1 || true
	selinux_cfg=$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)
	modules=$(semodule -l | awk '{ print $1 }' | sort | tr '\n' ' ')
	getsebool -a > "$REC_DIR/booleans"
	chmod 0644 "$REC_DIR/booleans"
	home_saved=no
	if [ -e "$home" ]; then
		mv "$home" "$bak/pgsql"
		home_saved=yes
	fi
	tmp="$STATE_FILE.tmp"
	{
		echo "pg_was_enabled=$was_enabled"
		echo "pg_was_active=$was_active"
		echo "home_saved=$home_saved"
		echo "selinux_cfg=$selinux_cfg"
		echo "modules=$modules"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

if ! { rpm -q postgresql-server >/dev/null 2>&1 &&
	rpm -q policycoreutils-python-utils >/dev/null 2>&1; }; then
	quiet dnf -y -q install postgresql-server policycoreutils-python-utils ||
		die "could not install postgresql-server and policycoreutils-python-utils."
fi

# First run only, once semanage is there: the local SELinux
# customizations before the lab
if [ ! -r "$REC_DIR/semanage.export" ]; then
	semanage export > "$REC_DIR/semanage.export.tmp"
	chmod 0644 "$REC_DIR/semanage.export.tmp"
	mv "$REC_DIR/semanage.export.tmp" "$REC_DIR/semanage.export"
fi

# Put the local SELinux customizations (file context and port rules,
# booleans) back to the recorded state, and remove policy modules that
# were added at priority 400 since the first start (audit2allow modules,
# permissive domains)
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	now=$(semanage export 2>/dev/null) || return 0
	# Rules added since the first start go, rules removed come back
	printf '%s\n' "$now" | grep -E '^(fcontext|port) -a ' |
		grep -vxF -f "$rec" | sed 's/^\([a-z]*\) -a /\1 -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	grep -E '^(fcontext|port) -a ' "$rec" |
		grep -vxF -f <(printf '%s\n' "$now") |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	# Booleans: the persistent values, then the runtime values
	if [ "$(printf '%s\n' "$now" | grep '^boolean -m ' | sort)" != \
		"$(grep '^boolean -m ' "$rec" | sort)" ]; then
		semanage boolean -D >/dev/null 2>&1 || true
		grep '^boolean -m ' "$rec" | while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	fi
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r m; do
			line=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$line" ] && setsebool "$m" "$line" >/dev/null 2>&1
			true
		done
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

# Reset what a previous run or the solution left behind
systemctl disable --now postgresql >/dev/null 2>&1 || true
systemctl reset-failed postgresql >/dev/null 2>&1 || true
rm -rf "$home"
selinux_restore
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

for p in 5432 5433; do
	if [ -n "$(ss -H -tln "sport = :$p" 2>/dev/null)" ]; then
		die "another service already listens on TCP port $p."
	fi
done
if semanage port -l 2>/dev/null | awk '$2 == "tcp"' |
	grep -Eq '[[:space:],]5433(,|[[:space:]]|$)'; then
	die "TCP port 5433 already has an SELinux port type."
fi

# A fresh cluster with scram-sha-256 password hashes, in a new home
# directory of the user postgres as the package creates it
install -d -o postgres -g postgres -m 0700 "$home"
restorecon "$home"
quiet postgresql-setup --initdb || die "cannot initialise the database cluster."
conf=$DATA/postgresql.conf
sed -i "s/^#\{0,1\}password_encryption = [^#]*/password_encryption = 'scram-sha-256'	/" "$conf"
grep -q "^password_encryption = 'scram-sha-256'" "$conf" ||
	echo "password_encryption = 'scram-sha-256'" >> "$conf"

quiet systemctl start postgresql || die "cannot start postgresql."

pgsu() {
	(cd /tmp && runuser -u postgres -- psql -X -qAt -v ON_ERROR_STOP=1 "$@")
}

ready=no
for _ in $(seq 1 30); do
	if pgsu -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
		ready=yes
		break
	fi
	sleep 1
done
[ "$ready" = yes ] || die "postgresql does not accept connections."

pgsu -d postgres >/dev/null <<SQL || die "cannot create the lab data."
CREATE ROLE labapp LOGIN PASSWORD '$PASSWORD';
CREATE DATABASE labdb;
GRANT CONNECT ON DATABASE labdb TO labapp;
SQL
pgsu -d labdb >/dev/null <<'SQL' || die "cannot create the lab data."
CREATE TABLE public.inventory (
	id integer PRIMARY KEY,
	item text NOT NULL,
	qty integer NOT NULL
);
INSERT INTO public.inventory (id, item, qty) VALUES
	(1, 'cable cat6 2m', 140),
	(2, 'cable cat6 5m', 85),
	(3, 'patch panel 24 port', 6),
	(4, 'switch 8 port', 12),
	(5, 'switch 24 port', 4),
	(6, 'rack shelf', 9),
	(7, 'power strip', 22),
	(8, 'usb keyboard', 31),
	(9, 'usb mouse', 47),
	(10, 'monitor 24 inch', 15),
	(11, 'docking station', 8),
	(12, 'headset', 26);
GRANT USAGE ON SCHEMA public TO labapp;
GRANT SELECT ON public.inventory TO labapp;
SQL

sum=$(pgsu -d labdb -c 'COPY (SELECT * FROM public.inventory ORDER BY id) TO STDOUT' |
	md5sum | awk '{ print $1 }')
[ -n "$sum" ] || die "cannot compute the checksum of the lab data."

quiet systemctl stop postgresql || die "cannot stop postgresql."

# The faults: port 5433 without a port type, an invalid method in
# pg_hba.conf, a data directory that others can read
sed -i 's/^#\{0,1\}port = [0-9]*/port = 5433/' "$conf"
grep -q '^port = 5433' "$conf" || echo 'port = 5433' >> "$conf"
hba=$DATA/pg_hba.conf
awk '!done && /^host[[:space:]]/ {
	print "host    labdb           labapp          127.0.0.1/32            scram-sha256"
	done = 1
}
{ print }' "$hba" > "$hba.tmp"
cat "$hba.tmp" > "$hba"
rm -f "$hba.tmp"
chmod 0755 "$DATA"

# The checksum the grader compares
tmp="$STATE_FILE.tmp"
{
	grep -v '^sum_' "$STATE_FILE"
	echo "sum_data=$sum"
} > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$STATE_FILE"

# postgresql was tried once and failed; it stays disabled
if systemctl start postgresql >/dev/null 2>&1; then
	systemctl stop postgresql >/dev/null 2>&1 || true
	die "postgresql started although it should fail."
fi
systemctl disable postgresql >/dev/null 2>&1 || true
exit 0
