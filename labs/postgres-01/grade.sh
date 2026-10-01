#!/bin/bash
# postgres-01 grader
source /opt/linux-labs/lib/grading.sh

grade_begin postgres-01
grade_require_state postgres-01

cluster_initialised() {
	[ -s /var/lib/pgsql/data/PG_VERSION ] && [ -f /var/lib/pgsql/data/postgresql.conf ]
}

postgres_listens() {
	ss -H -tlnp 'sport = :5432' | grep -q '"postgres"'
}

postgres_user_query() {
	local out
	out=$(cd /tmp && runuser -u postgres -- psql -d postgres -tAc 'SELECT 1' 2>/dev/null) || return 1
	[ "$out" = 1 ]
}

criterion "Package postgresql-server is installed" rpm -q postgresql-server
criterion "Cluster is initialised in /var/lib/pgsql/data" cluster_initialised
criterion "Service postgresql is running" systemctl is-active --quiet postgresql
criterion "Service postgresql is enabled at boot" systemctl is-enabled --quiet postgresql
criterion "PostgreSQL listens on TCP port 5432" postgres_listens
criterion "User postgres can query database postgres" postgres_user_query
grade_end
