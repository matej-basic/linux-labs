#!/bin/bash

# Remove test configurations and restore default firewall state
echo "Cleaning up firewall-03 lab..."

# Remove masquerading from internal zone
firewall-cmd --permanent --zone=internal --remove-masquerade >/dev/null 2>&1

# Remove port forwarding from public zone
firewall-cmd --permanent --zone=public --remove-forward-port=port=8443:proto=tcp:toport=443 >/dev/null 2>&1

# Remove custom-app service from public zone
firewall-cmd --permanent --zone=public --remove-service=custom-app >/dev/null 2>&1

# Remove HTTP service from public zone
firewall-cmd --permanent --zone=public --remove-service=http >/dev/null 2>&1

# Remove source from internal zone
firewall-cmd --permanent --zone=internal --remove-source=10.0.0.0/8 >/dev/null 2>&1

# Delete custom service definition
firewall-cmd --delete-service=custom-app >/dev/null 2>&1
rm -f /etc/firewalld/services/custom-app.xml

# Reload firewall configuration
firewall-cmd --reload >/dev/null 2>&1

echo "Firewall lab cleanup complete."

