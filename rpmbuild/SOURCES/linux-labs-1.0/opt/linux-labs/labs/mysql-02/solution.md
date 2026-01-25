# MySQL 02 Solution

Create a MySQL database and user with appropriate privileges.

## Commands to reach the expected state:

```bash
# Create the database
sudo mysql -u root -plabpassword -e "CREATE DATABASE labdb;"

# Create the user
sudo mysql -u root -plabpassword -e "CREATE USER 'labuser'@'localhost' IDENTIFIED BY 'userpass123';"

# Grant privileges on the database to the user
sudo mysql -u root -plabpassword -e "GRANT SELECT, INSERT, UPDATE, DELETE ON labdb.* TO 'labuser'@'localhost';"

# Flush privileges to apply changes
sudo mysql -u root -plabpassword -e "FLUSH PRIVILEGES;"

# Create the users table in labdb
sudo mysql -u root -plabpassword labdb -e "
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
);
"

# Insert sample records
sudo mysql -u root -plabpassword labdb -e "
INSERT INTO users (name, email) VALUES 
('John Doe', 'john@example.com'),
('Jane Smith', 'jane@example.com');
"
```

## Verify:

```bash
# Check if database exists
mysql -u root -plabpassword -e "SHOW DATABASES;" | grep labdb

# Check if user exists
mysql -u root -plabpassword -e "SELECT User, Host FROM mysql.user WHERE User='labuser';"

# Check user privileges
mysql -u root -plabpassword -e "SHOW GRANTS FOR 'labuser'@'localhost';"

# Connect as labuser and verify access
mysql -u labuser -puserpass123 labdb -e "SELECT * FROM users;"

# Run the grading script
sudo labctl grade mysql-02
```

