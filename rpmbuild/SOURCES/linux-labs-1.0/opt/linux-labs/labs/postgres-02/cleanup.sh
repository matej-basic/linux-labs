#!/bin/bash
# Drop database and role created during the lab
echo "Cleaning up PostgreSQL Database and Role Management (postgres-02) lab environment..."

sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS labdb;" > /dev/null 2>&1
sudo -u postgres psql -d postgres -c "DROP ROLE IF EXISTS labuser;" > /dev/null 2>&1

# End of cleanup message
echo "Cleanup completed."

