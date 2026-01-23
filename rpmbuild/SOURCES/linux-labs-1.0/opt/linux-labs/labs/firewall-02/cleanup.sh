#!/bin/bash

# Remove test rules and restore default firewall state
echo "Cleaning up firewall-02 lab..."

# Remove the rich rule from public zone
firewall-cmd --permanent --zone=public \
  --remove-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port protocol="tcp" port="443" accept' >/dev/null 2>&1

# Remove interface from trusted zone (try common interface names)
for iface in eth0 eth1 ens0 ens1; do
  firewall-cmd --permanent --zone=trusted --remove-interface=$iface >/dev/null 2>&1
done

# Reload firewall configuration
firewall-cmd --reload >/dev/null 2>&1

echo "Firewall lab cleanup complete."

