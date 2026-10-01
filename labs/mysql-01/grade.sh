#!/bin/bash
# mysql-01 grader
source /opt/linux-labs/lib/grading.sh

# Listening TCP socket on port 3306 (IPv4 or IPv6)
port_listening() {
	ss -H -tln | grep -Eq '[:.]3306[[:space:]]'
}

# Login as root with the lab password returns a result
root_login_works() {
	MYSQL_PWD=labpassword mysql -u root -e 'SELECT 1' | grep -q 1
}

grade_begin mysql-01
criterion "Package mysql-server is installed" rpm -q mysql-server
criterion "Service mysqld is running" systemctl is-active --quiet mysqld
criterion "Service mysqld is enabled at boot" systemctl is-enabled --quiet mysqld
criterion "MySQL listens on port 3306/tcp" port_listening
criterion "MySQL root login works with password labpassword" root_login_works
grade_end
