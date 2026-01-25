# PostgreSQL 01 Solution

Install PostgreSQL Server and verify basic connectivity.

## Commands to reach the expected state:

```bash
# Install PostgreSQL Server and contrib
sudo dnf install -y postgresql-server postgresql-contrib

# Initialize the database cluster
sudo postgresql-setup initdb

# Start the PostgreSQL service
sudo systemctl start postgresql

# Enable PostgreSQL to start on boot
sudo systemctl enable postgresql

# Configure PostgreSQL to allow password authentication (optional for basic setup)
sudo sed -i 's/^host.*all.*all.*127.0.0.1\/32.*ident$/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/^host.*all.*all.*::1\/128.*ident$/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql
```

## Verify:

```bash
# Check if PostgreSQL is installed
rpm -q postgresql-server

# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check if port 5432 is listening
sudo ss -tlnp | grep 5432

# Connect to PostgreSQL as postgres user
cd /tmp && sudo -u postgres psql -c "SELECT version();"

# Connect to specific database
cd /tmp && sudo -u postgres psql -d postgres -c "SELECT current_database();"

# Run the grading script
sudo labctl grade postgres-01
```

