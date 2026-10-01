# mysql-01: MySQL installation and root password

## Hints

1. Three separate things are needed: the package, a running service
   that survives a reboot, and a password for the database account.
   Port 3306 needs no work of its own.
2. Package and service are handled by dnf and systemctl. In man
   systemctl, look at the enable command and its --now option.
3. A fresh MySQL installation lets root in without a password when the
   mysql client runs as the Linux root user. Change the password with
   the SQL statement ALTER USER, described in the MySQL manual.

## Solution

1. [sudo] Install MySQL Server:

   ```bash
   sudo dnf install -y mysql-server
   ```

2. [sudo] Start the service and enable it at boot:

   ```bash
   sudo systemctl enable --now mysqld
   ```

3. [sudo] Set the root password. A fresh installation lets root in
   without a password, so no password is needed for this command:

   ```bash
   sudo mysql -u root \
     -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'labpassword';"
   ```

## Verification

```bash
rpm -q mysql-server
systemctl is-active mysqld
ss -tln | grep 3306
mysql -u root -plabpassword -e "SELECT VERSION();"
labctl grade mysql-01
```

## Explanation

On Rocky Linux 8 and 9 the package mysql-server comes from AppStream
and ships the unit mysqld. mariadb-server is a separate package with
the unit mariadb and cannot be installed alongside it. The service
listens on 3306 as soon as it starts, so no extra configuration is
needed.

The MySQL root account has an empty password after installation.
ALTER USER sets the new one immediately, and FLUSH PRIVILEGES is not
required for it. The grader logs in over the local socket, so the
password is checked without any firewall involvement.
