#!/bin/bash

# Reset lab state
sudo semodule -r myapp_custom &>/dev/null || true
sudo rm -rf /webapp
sudo rm -f /etc/httpd/conf.d/lab-port.conf
sudo semanage port -d -t http_port_t -p tcp 8081 >/dev/null 2>&1 || true

# Ensure selinux is in enforcing mode
sudo setenforce 1 2>/dev/null || true

# Ensure apache and SELinux tools are installed
sudo dnf install -y httpd policycoreutils-python-utils &>/dev/null

# Prepare content
sudo mkdir -p /webapp/porttest
sudo bash -c 'echo "Custom port test page" > /webapp/porttest/index.html'
sudo chown -R apache:apache /webapp/porttest

# Configure Apache to listen on 8081 without SELinux port context (will fail until fixed)
sudo bash -c 'cat > /etc/httpd/conf.d/lab-port.conf <<"CONF"
Listen 8081
<VirtualHost *:8081>
    DocumentRoot /webapp/porttest
    <Directory /webapp/porttest>
        Require all granted
    </Directory>
</VirtualHost>
CONF'

# Stop httpd so learner starts it after fixing SELinux port label
sudo systemctl disable --now httpd >/dev/null 2>&1 || true

cat <<'EOF'

=====================================================
LAB: SELinux Port Labeling for Non-Standard HTTP (selinux-03)
=====================================================

OBJECTIVE
Allow Apache (httpd_t) to bind to TCP port 8081 and serve content from
/webapp/porttest by setting the correct SELinux port and file contexts
instead of weakening policy.

SCENARIO
- Apache is configured to listen on 8081 with a vhost serving /webapp/porttest
- SELinux blocks httpd_t from binding to 8081 because the port is not labeled
   as http_port_t
- File context is not yet set for httpd content under /webapp/porttest
- Goal: Add the proper SELinux port mapping, set the content context, start
   Apache, and verify content

TASKS
1) Confirm the current block (optional):
   sudo systemctl start httpd   # should fail to bind 8081 due to SELinux

2) Label port 8081 for HTTP

3) Label the content for httpd

4) Start Apache and verify it runs on 8081:
   sudo systemctl start httpd
   sudo systemctl status httpd --no-pager

5) Test the page:
   curl -s http://localhost:8081/

Run grading when done:
  sudo labctl grade selinux-03

=====================================================

EOF
