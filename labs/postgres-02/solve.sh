#!/bin/bash
# Reference solution for postgres-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
sed -i -E \
  's/(127\.0\.0\.1\/32|::1\/128)(\s+)ident/\1\2md5/' \
  /var/lib/pgsql/data/pg_hba.conf
grep '^host' /var/lib/pgsql/data/pg_hba.conf
systemctl reload postgresql

# Step 2 [sudo]
sudo -iu postgres psql \
  -c "CREATE ROLE labuser WITH LOGIN PASSWORD 'userpass123';" \
  -c "CREATE DATABASE labdb;" \
  -c "GRANT CONNECT ON DATABASE labdb TO labuser;"

# Step 3 [sudo]
sudo -iu postgres psql -d labdb \
  -c "GRANT USAGE ON SCHEMA public TO labuser;" \
  -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT NOT NULL,
  email TEXT NOT NULL);" \
  -c "GRANT SELECT, INSERT, UPDATE, DELETE ON users TO labuser;" \
  -c "GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO labuser;" \
  -c "INSERT INTO users (name, email)
  VALUES ('John', 'a@example.com'), ('Jane', 'b@example.com');"

# Step 4 [user]
run_as_student <<'STEPS'
PGPASSWORD=userpass123 psql -h 127.0.0.1 -U labuser -d labdb -c 'SELECT * FROM users;'
STEPS
