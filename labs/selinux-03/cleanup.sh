#!/bin/bash

# Remove lab files and port label
sudo rm -rf /webapp
sudo rm -f /etc/httpd/conf.d/lab-port.conf
sudo semanage port -d -t http_port_t -p tcp 8081 >/dev/null 2>&1 || true

# Stop and disable apache, optional remove
sudo systemctl disable --now httpd >/dev/null 2>&1 || true
sudo dnf remove -y httpd >/dev/null 2>&1 || true

echo "Cleanup complete."
