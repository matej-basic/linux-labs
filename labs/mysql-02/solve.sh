#!/bin/bash
# Reference solution for mysql-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [user]
run_as_student <<'STEPS'
mysql -u root -plabpassword -e "CREATE DATABASE labdb" </dev/null
mysql -u root -plabpassword -e "CREATE USER 'labuser'@'localhost' IDENTIFIED BY 'userpass123'" </dev/null
mysql -u root -plabpassword -e "GRANT SELECT, INSERT, UPDATE, DELETE ON labdb.* TO 'labuser'@'localhost'" </dev/null
mysql -u root -plabpassword labdb -e "CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, email VARCHAR(100) NOT NULL)" </dev/null
mysql -u root -plabpassword labdb -e "INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com'), ('Jane Smith', 'jane@example.com')" </dev/null
STEPS
