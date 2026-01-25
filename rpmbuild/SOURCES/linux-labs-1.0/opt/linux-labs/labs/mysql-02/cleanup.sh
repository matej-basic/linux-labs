#!/bin/bash
# Drop database and user created during the lab
echo "Cleaning up MySQL Database and User Management (mysql-02) lab environment..."

mysql -u root -plabpassword -e "DROP DATABASE IF EXISTS labdb;" 2>/dev/null
mysql -u root -plabpassword -e "DROP USER IF EXISTS 'labuser'@'localhost';" 2>/dev/null

# End of cleanup message
echo "Cleanup completed."

