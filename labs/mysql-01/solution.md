# MySQL 01 Solution

Install MySQL Server and configure basic connectivity.

## Commands to reach the expected state:

```bash
# Install MySQL Server
sudo dnf install -y mysql-server

# Start the MySQL service
sudo systemctl start mysqld

# Enable MySQL to start on boot
sudo systemctl enable mysqld

# Set root password
sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'labpassword';"

# Flush privileges to apply changes
sudo mysql -u root -plabpassword -e "FLUSH PRIVILEGES;"
```

## Verify:

```bash
# Check if MySQL is installed
rpm -q mysql-server

# Check if MySQL is running
sudo systemctl status mysqld

# Check if port 3306 is listening
sudo ss -tlnp | grep 3306

# Test connection with new password
mysql -u root -plabpassword -e "SELECT VERSION();"

# Run the grading script
sudo labctl grade mysql-01
```

