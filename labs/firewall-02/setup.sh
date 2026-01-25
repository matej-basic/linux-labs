#!/bin/bash

# Print that we are setting up the lab
echo "Setting up firewall-02 lab..."

# Reset lab state - remove any test rules if they exist
firewall-cmd --remove-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port protocol="tcp" port="443" accept' --zone=public --permanent >/dev/null 2>&1
firewall-cmd --permanent --zone=trusted --remove-interface=eth0 >/dev/null 2>&1
firewall-cmd --permanent --zone=trusted --remove-interface=eth1 >/dev/null 2>&1
firewall-cmd --permanent --zone=trusted --remove-interface=ens0 >/dev/null 2>&1
firewall-cmd --permanent --zone=trusted --remove-interface=ens1 >/dev/null 2>&1
firewall-cmd --reload >/dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: Rich Rules and Zones (firewall-02)
====================================================

OBJECTIVE:
Master firewalld rich rules and zone management
for more granular access control.

REQUIREMENTS:
1. Create a rich rule that allows port 443 (HTTPS)
   from a specific source network (192.168.1.0/24)

2. Set the "trusted" zone for a specific interface
   (Use eth0, eth1, ens0, or ens1 - whichever is available)

3. Verify the rich rule was added

4. Verify the zone assignment for the interface

5. Reload the firewall to apply permanent changes

NOTES:
- Use --permanent flag to make rules survive reboot
- Rich rules provide advanced filtering capabilities
- Zones define trust levels and rules for network interfaces
- The trusted zone allows all traffic by default
- The public zone is the default restrictive zone

USEFUL COMMANDS:
- List all rich rules: firewall-cmd --list-rich-rules --zone=public
- List active zones: firewall-cmd --get-active-zones
- Check zone info: firewall-cmd --list-all --zone=public
- Reload rules: firewall-cmd --reload

When ready, run:
  sudo labctl grade firewall-02

====================================================

EOF

