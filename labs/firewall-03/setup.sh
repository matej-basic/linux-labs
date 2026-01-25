#!/bin/bash

# Print that we are setting up the lab
echo "Setting up firewall-03 lab..."

# Reset lab state - remove test configurations if they exist
firewall-cmd --permanent --zone=internal --remove-masquerade >/dev/null 2>&1
firewall-cmd --permanent --zone=public --remove-forward-port=port=8443:proto=tcp:toport=443 >/dev/null 2>&1
firewall-cmd --permanent --remove-service=custom-app >/dev/null 2>&1
firewall-cmd --delete-service=custom-app >/dev/null 2>&1
rm -f /etc/firewalld/services/custom-app.xml
firewall-cmd --reload >/dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: Advanced Firewall Scenarios (firewall-03)
====================================================

OBJECTIVE:
Configure complex firewall scenarios including
masquerading, port forwarding, custom services,
and multi-zone management.

REQUIREMENTS:

1. Enable masquerading on the internal zone
   (Allows systems behind this zone to hide behind 
    the firewall's IP for outbound traffic)

2. Configure port forwarding on the public zone
   Forward external port 8443 to internal port 443

3. Create a custom service definition for a sample app
   - Name: custom-app
   - Ports: 9090/tcp and 9090/udp (example)
   - Description: Sample Custom Application Service
   - Save the XML file to /etc/firewalld/services/custom-app.xml
   - Add this service to the public zone
   
4. Add HTTP to the public zone (for completeness)

5. Reload firewall to apply all permanent rules
   Example: sudo firewall-cmd --reload

6. Verify all configurations

NOTES:
- Masquerading enables Network Address Translation (NAT)
- Port forwarding redirects traffic from one port to another
- Custom services must be defined in XML format
- Zone management allows different rules for different networks
- All changes use --permanent to survive reboot
- Always reload after making permanent changes

USEFUL COMMANDS:
- List zone info: firewall-cmd --list-all --zone=ZONE
- Check masquerade: firewall-cmd --zone=internal --query-masquerade
- List services: firewall-cmd --get-services
- List custom services: ls /etc/firewalld/services/
- Reload rules: firewall-cmd --reload
- Get active zones: firewall-cmd --get-active-zones

When ready, run:
  sudo labctl grade firewall-03

====================================================

EOF

