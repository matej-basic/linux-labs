# PostgreSQL 02 Solution

Create a PostgreSQL database and role with appropriate privileges.

## Commands to reach the expected state:

```bash
# Configure PostgreSQL to allow password authentication
sudo sed -i 's/^host.*all.*all.*127.0.0.1\/32.*ident$/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/^host.*all.*all.*::1\/128.*ident$/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql

# Create the role
cd /tmp && sudo -u postgres psql -c "CREATE ROLE labuser WITH LOGIN PASSWORD 'userpass123';"

# Create the database
cd /tmp && sudo -u postgres psql -c "CREATE DATABASE labdb OWNER postgres;"

# Grant CONNECT privilege on database
cd /tmp && sudo -u postgres psql -c "GRANT CONNECT ON DATABASE labdb TO labuser;"

# Grant USAGE on public schema
cd /tmp && sudo -u postgres psql -d labdb -c "GRANT USAGE ON SCHEMA public TO labuser;"

# Create the users table
cd /tmp && sudo -u postgres psql -d labdb -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
);
"

# Grant privileges on the table
cd /tmp && sudo -u postgres psql -d labdb -c "GRANT SELECT, INSERT, UPDATE, DELETE ON users TO labuser;"
cd /tmp && sudo -u postgres psql -d labdb -c "GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO labuser;"

# Insert sample records
cd /tmp && sudo -u postgres psql -d labdb -c "
INSERT INTO users (name, email) VALUES 
('John Doe', 'john@example.com'),
('Jane Smith', 'jane@example.com');
"
```

## Verify:

```bash
# Check if database exists
cd /tmp && sudo -u postgres psql -l | grep labdb

# Check if role exists
cd /tmp && sudo -u postgres psql -c "\du" | grep labuser

# Check privileges on database
cd /tmp && sudo -u postgres psql -c "\l" | grep labdb

# Connect as labuser and verify access
export PGPASSWORD=userpass123
psql -U labuser -d labdb -h localhost -c "SELECT * FROM users;"

# Check table privileges
cd /tmp && sudo -u postgres psql -d labdb -c "\dp users"

# Run the grading script
sudo labctl grade postgres-02
```

