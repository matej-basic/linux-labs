#!/bin/bash
# postgres-04 grader
source /opt/linux-labs/lib/grading.sh

LAB=postgres-04
STATE_FILE=/opt/linux-labs/state/$LAB
DATA=/var/lib/pgsql/data
PASSWORD=Stock-2026
PORT=5433
ROWS=12

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# Query as the postgres superuser over the local socket of port 5433
q() {
	(cd /tmp && runuser -u postgres -- psql -X -qAt -p "$PORT" -d "$1" -c "$2" 2>/dev/null)
}

# Query as labapp over TCP with the given password
qu() {
	PGPASSWORD="$1" PGPASSFILE=/dev/null PGCONNECT_TIMEOUT=5 \
		psql -X -qAt -h 127.0.0.1 -p "$PORT" -U labapp -d labdb -c "$2" \
		</dev/null 2>/dev/null
}

pg_enabled_running() {
	systemctl is-enabled --quiet postgresql && systemctl is-active --quiet postgresql
}

# A postgres listener on port 5433 that covers 127.0.0.1
listens() {
	ss -H -tlnp "sport = :$PORT" 2>/dev/null |
		awk '$4 ~ /^(127\.0\.0\.1|0\.0\.0\.0|\*):/' |
		grep -Eq '"(postgres|postmaster)"'
}

# Port 5433/tcp is in a postgresql_port_t entry (single port or range)
port_type_ok() {
	semanage port -l 2>/dev/null | awk -v p="$PORT" '
		$1 == "postgresql_port_t" && $2 == "tcp" {
			for (i = 3; i <= NF; i++) {
				v = $i
				sub(/,$/, "", v)
				n = split(v, r, "-")
				if (n == 1 && v + 0 == p) found = 1
				if (n == 2 && r[1] + 0 <= p && p <= r[2] + 0) found = 1
			}
		}
		END { exit !found }'
}

labapp_reads() {
	[ "$(qu "$PASSWORD" 'SELECT count(*) FROM public.inventory')" = "$ROWS" ]
}

# A wrong password is rejected (only meaningful when the right one works)
wrong_password_rejected() {
	labapp_reads || return 1
	[ -z "$(qu "wrong-$$" 'SELECT 1')" ]
}

data_unchanged() {
	local want got
	want=$(state_value sum_data)
	[ -n "$want" ] || return 1
	[ "$(q labdb 'SELECT count(*) FROM public.inventory')" = "$ROWS" ] || return 1
	got=$(cd /tmp && runuser -u postgres -- psql -X -qAt -p "$PORT" -d labdb \
		-c 'COPY (SELECT * FROM public.inventory ORDER BY id) TO STDOUT' \
		2>/dev/null | md5sum | awk '{ print $1 }')
	[ "$got" = "$want" ]
}

data_dir_ok() {
	case "$(stat -c '%a %U' "$DATA" 2>/dev/null)" in
	"700 postgres" | "750 postgres") return 0 ;;
	esac
	return 1
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

# Modules that are loaded now and were not loaded at the first start
new_modules() {
	local before m
	before=$(state_value modules)
	for m in $(semodule -l 2>/dev/null | awk '{ print $1 }'); do
		case " $before " in
		*" $m "*) ;;
		*) echo "$m" ;;
		esac
	done
}

# postgresql_t is not permissive, and no permissive domain module is new
no_permissive_added() {
	! semanage permissive -l 2>/dev/null | grep -qw postgresql_t || return 1
	! new_modules | grep -q '^permissive_'
}

# Other new modules (audit2allow and the like)
no_modules_added() {
	! new_modules | grep -vq '^permissive_'
}

grade_begin postgres-04
grade_require_state postgres-04 "$STATE_FILE"

criterion "postgresql is enabled and running" pg_enabled_running
criterion "PostgreSQL listens on 127.0.0.1 port $PORT/tcp" listens
criterion "Port $PORT/tcp has the SELinux type postgresql_port_t" port_type_ok
criterion "labapp reads $ROWS rows from inventory over TCP" labapp_reads
criterion "A wrong password for labapp is rejected over TCP" wrong_password_rejected
criterion "The data in labdb is unchanged" data_unchanged
criterion "$DATA is owned by postgres, mode 0700 or 0750" data_dir_ok
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
criterion "No permissive domains were added" no_permissive_added
criterion "No policy modules were added" no_modules_added
grade_end
